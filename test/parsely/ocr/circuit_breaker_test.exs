defmodule Parsely.OCR.CircuitBreakerTest do
  use ExUnit.Case, async: false  # Changed to false to avoid shared state issues

  alias Parsely.OCR.CircuitBreaker

  setup do
    # Start a test circuit breaker with unique name for each test
    test_name = :"test_circuit_breaker_#{System.unique_integer([:positive])}"
    {:ok, pid} = CircuitBreaker.start_link(name: test_name)
    %{circuit_breaker: pid, test_name: test_name}
  end

  test "successful calls pass through", %{test_name: test_name} do
    fun = fn -> {:ok, "success"} end

    assert CircuitBreaker.call(fun, name: test_name) == {:ok, {:ok, "success"}}
  end

  test "failed calls are tracked", %{test_name: test_name} do
    fun = fn -> raise "test error" end

    assert CircuitBreaker.call(fun, name: test_name) == {:error, :api_failure}
  end

  test "circuit opens after failure threshold", %{test_name: test_name} do
    # Configure low threshold for testing
    Application.put_env(:parsely, :ocr,
      circuit_breaker: [failure_threshold: 2],
      rate_limit: [max_requests: 1000, window_ms: 60000]
    )

    fun = fn -> raise "test error" end

    # First failure
    assert CircuitBreaker.call(fun, name: test_name) == {:error, :api_failure}

    # Second failure should open circuit
    assert CircuitBreaker.call(fun, name: test_name) == {:error, :api_failure}

    # Third call should be rejected due to open circuit
    assert CircuitBreaker.call(fun, name: test_name) == {:error, :circuit_open}
  end

  test "circuit can be reset", %{test_name: test_name} do
    fun = fn -> raise "test error" end

    # Cause failures to open circuit
    CircuitBreaker.call(fun, name: test_name)
    CircuitBreaker.call(fun, name: test_name)

    # Reset circuit
    assert CircuitBreaker.reset(name: test_name) == :ok

    # Should work again
    success_fun = fn -> {:ok, "success"} end
    assert CircuitBreaker.call(success_fun, name: test_name) == {:ok, {:ok, "success"}}
  end

  test "rate limiting works", %{test_name: test_name} do
    # Configure low rate limit for testing
    Application.put_env(:parsely, :ocr,
      circuit_breaker: [failure_threshold: 10],
      rate_limit: [max_requests: 2, window_ms: 1000]
    )

    fun = fn -> {:ok, "success"} end

    # First two calls should succeed
    assert CircuitBreaker.call(fun, name: test_name) == {:ok, {:ok, "success"}}
    assert CircuitBreaker.call(fun, name: test_name) == {:ok, {:ok, "success"}}

    # Third call should be rate limited
    assert CircuitBreaker.call(fun, name: test_name) == {:error, :rate_limit_exceeded}
  end

  test "get_state returns current state", %{test_name: test_name} do
    state = CircuitBreaker.get_state(name: test_name)

    assert state.state == :closed
    assert state.failure_count == 0
    assert state.success_count == 0
    assert state.request_count == 0
  end
end
