defmodule Parsely.ImageService do
  @moduledoc """
  Service for handling image uploads and storage.
  """

  @doc """
  Uploads a base64 image to S3 and returns the URL.
  """
  def upload_image(base64_image, filename) do
    # Remove the data:image/jpeg;base64, prefix if present
    image_data = String.replace(base64_image, ~r/^data:image\/[^;]+;base64,/, "")

    # Decode base64 to binary
    case Base.decode64(image_data) do
      {:ok, binary_data} ->
        # For now, we'll store locally. In production, you'd upload to S3
        store_image_locally(binary_data, filename)
      :error ->
        {:error, "Invalid base64 image data"}
    end
  end

  defp store_image_locally(binary_data, filename) do
    # Create uploads directory if it doesn't exist
    uploads_dir = "priv/static/uploads"
    File.mkdir_p!(uploads_dir)

    # Generate unique filename
    unique_filename = "#{System.system_time()}_#{filename}"
    file_path = Path.join(uploads_dir, unique_filename)

    case File.write(file_path, binary_data) do
      :ok ->
        # Return the URL path for the uploaded image
        {:ok, "/uploads/#{unique_filename}"}
      {:error, reason} ->
        {:error, "Failed to save image: #{reason}"}
    end
  end

  @doc """
  Uploads image to S3 (for production use).
  """
  def upload_to_s3(base64_image, filename) do
    # Remove the data:image/jpeg;base64, prefix if present
    image_data = String.replace(base64_image, ~r/^data:image\/[^;]+;base64,/, "")

    # Decode base64 to binary
    case Base.decode64(image_data) do
      {:ok, binary_data} ->
        bucket = System.get_env("AWS_S3_BUCKET") || "parsely-business-cards"
        key = "business-cards/#{System.system_time()}_#{filename}"

        # Upload to S3
        ExAws.S3.upload(bucket, key, binary_data)
        |> ExAws.request()
        |> case do
          {:ok, _response} ->
            {:ok, "https://#{bucket}.s3.amazonaws.com/#{key}"}
          {:error, reason} ->
            {:error, "S3 upload failed: #{reason}"}
        end
      :error ->
        {:error, "Invalid base64 image data"}
    end
  end
end
