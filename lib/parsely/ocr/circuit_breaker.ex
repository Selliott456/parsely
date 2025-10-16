defmodule Parsely.OCR.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for OCR API calls.

  Provides rate limiting and failure handling to prevent overwhelming
  external OCR services and handle temporary outages gracefully.
  """

  use GenServer
  require Logger

  @type state :: :closed | :open | :half_open
  @type circuit_state :: %{
    state: state(),
    failure_count: non_neg_integer(),
    last_failure_time: integer() | nil,
    success_count: non_neg_integer(),
    request_count: non_neg_integer(),
    window_start: integer()
  }

  ## Client API

  @doc """
  Starts the circuit breaker.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Calls a function through the circuit breaker.
  Returns {:ok, result} on success or {:error, reason} on failure.
  """
  def call(fun, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, {:call, fun, opts}, :infinity)
  end

  @doc """
  Gets the current circuit breaker state.
  """
  def get_state(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, :get_state)
  end

  @doc """
  Resets the circuit breaker to closed state.
  """
  def reset(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.call(name, :reset)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    config = Application.get_env(:parsely, :ocr, [])
    circuit_config = Keyword.get(config, :circuit_breaker, [])
    rate_config = Keyword.get(config, :rate_limit, [])

    state = %{
      state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      success_count: 0,
      request_count: 0,
      window_start: System.monotonic_time(:millisecond),
      failure_threshold: Keyword.get(circuit_config, :failure_threshold, 5),
      recovery_timeout: Keyword.get(circuit_config, :recovery_timeout, 60_000),
      half_open_max_calls: Keyword.get(circuit_config, :half_open_max_calls, 3),
      max_requests: Keyword.get(rate_config, :max_requests, 500),
      window_ms: Keyword.get(rate_config, :window_ms, 3_600_000)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:call, fun, _opts}, _from, state) do
    case check_rate_limit(state) do
      {:ok, new_state} ->
        case check_circuit_state(new_state) do
          {:ok, updated_state} ->
            execute_call(fun, updated_state)
          {:error, reason, updated_state} ->
            {:reply, {:error, reason}, updated_state}
        end
      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, Map.take(state, [:state, :failure_count, :success_count, :request_count]), state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{state | state: :closed, failure_count: 0, success_count: 0}
    Logger.info("Circuit breaker reset to closed state")
    {:reply, :ok, new_state}
  end

  ## Private Functions

  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)

    # Reset window if needed
    state = if now - state.window_start > state.window_ms do
      %{state | request_count: 0, window_start: now}
    else
      state
    end

    if state.request_count >= state.max_requests do
      Logger.warning("Rate limit exceeded: #{state.request_count}/#{state.max_requests} requests in window")
      {:error, :rate_limit_exceeded, state}
    else
      {:ok, %{state | request_count: state.request_count + 1}}
    end
  end

  defp check_circuit_state(state) do
    case state.state do
      :closed ->
        {:ok, state}

      :open ->
        now = System.monotonic_time(:millisecond)
        if state.last_failure_time && (now - state.last_failure_time) > state.recovery_timeout do
          Logger.info("Circuit breaker transitioning to half-open state")
          {:ok, %{state | state: :half_open, success_count: 0}}
        else
          {:error, :circuit_open, state}
        end

      :half_open ->
        if state.success_count >= state.half_open_max_calls do
          Logger.info("Circuit breaker transitioning to closed state")
          {:ok, %{state | state: :closed, failure_count: 0, success_count: 0}}
        else
          {:ok, state}
        end
    end
  end

  defp execute_call(fun, state) do
    try do
      result = fun.()
      handle_success(state, result)
    rescue
      error ->
        handle_failure(state, error)
    catch
      :exit, reason ->
        handle_failure(state, {:exit, reason})
      kind, reason ->
        handle_failure(state, {kind, reason})
    end
  end

  defp handle_success(state, result) do
    new_state = case state.state do
      :half_open ->
        %{state | success_count: state.success_count + 1}
      _ ->
        %{state | failure_count: 0}
    end

    {:reply, {:ok, result}, new_state}
  end

  defp handle_failure(state, error) do
    Logger.warning("OCR API call failed: #{inspect(error)}")

    new_failure_count = state.failure_count + 1
    now = System.monotonic_time(:millisecond)

    new_state = %{
      state |
      failure_count: new_failure_count,
      last_failure_time: now,
      success_count: 0
    }

    # Check if we should open the circuit
    final_state = if new_failure_count >= state.failure_threshold do
      Logger.error("Circuit breaker opening due to #{new_failure_count} consecutive failures")
      %{new_state | state: :open}
    else
      new_state
    end

    {:reply, {:error, :api_failure}, final_state}
  end
end
