const CameraCapture = {
  mounted() {
    console.log("CameraCapture hook mounted");
    this.stream = null;
    this.video = null;
    this.canvas = null;

    // Check if getUserMedia is supported
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      console.error("getUserMedia is not supported in this browser");
      this.updateCameraStatus("Camera not supported in this browser");
      return;
    }

    // Check if we're on HTTPS or localhost (required for camera access)
    if (
      location.protocol !== "https:" &&
      location.hostname !== "localhost" &&
      location.hostname !== "127.0.0.1"
    ) {
      console.error("Camera access requires HTTPS or localhost");
      this.updateCameraStatus("Camera access requires HTTPS or localhost");
      return;
    }

    // Start camera immediately when hook is mounted
    this.startCamera();

    // Also listen for the scan-card event from the dashboard (for navigation)
    this.handleEvent("scan-card", () => {
      console.log("Scan card event received, starting camera...");
      this.startCamera();
    });
  },

  async startCamera() {
    console.log("Starting camera...");
    console.log("Current location:", location.href);
    console.log("Protocol:", location.protocol);
    console.log("Hostname:", location.hostname);

    // Check if camera is already running
    if (this.stream) {
      console.log("Camera already running, stopping previous stream");
      this.stopCamera();
    }

    try {
      // Update UI to show camera is being requested
      this.updateCameraStatus("Requesting camera access...");

      // Request camera access
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "environment", // Use back camera on mobile
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });
      console.log("Camera access granted");
      console.log(
        "Stream tracks:",
        this.stream.getTracks().map((track) => track.kind)
      );

      // Create video element
      this.video = document.createElement("video");
      this.video.srcObject = this.stream;
      this.video.autoplay = true;
      this.video.playsInline = true;

      // Create canvas for capturing
      this.canvas = document.createElement("canvas");
      this.canvas.width = 1280;
      this.canvas.height = 720;

      // Wait for video to be ready
      this.video.addEventListener("loadedmetadata", () => {
        console.log("Video metadata loaded, setting up video display");
        console.log(
          "Video dimensions:",
          this.video.videoWidth,
          "x",
          this.video.videoHeight
        );
        this.updateCameraStatus("Camera ready");
        this.setupVideoDisplay();
      });

      this.video.addEventListener("error", (error) => {
        console.error("Video error:", error);
        this.updateCameraStatus("Camera error occurred");
      });
    } catch (error) {
      console.error("Error accessing camera:", error);
      console.error("Error name:", error.name);
      console.error("Error message:", error.message);
      this.updateCameraStatus(`Camera access denied: ${error.message}`);

      // Show more specific error messages
      if (error.name === "NotAllowedError") {
        alert(
          "Camera access was denied. Please allow camera access in your browser settings and refresh the page."
        );
      } else if (error.name === "NotFoundError") {
        alert("No camera found on this device.");
      } else if (error.name === "NotSupportedError") {
        alert("Camera is not supported in this browser.");
      } else {
        alert(`Unable to access camera: ${error.message}`);
      }
    }
  },

  setupVideoDisplay() {
    // Replace the placeholder with actual video
    const placeholder = document.querySelector(".bg-zinc-100");
    if (placeholder) {
      placeholder.innerHTML = "";
      placeholder.appendChild(this.video);
      placeholder.classList.remove("bg-zinc-100");
      placeholder.classList.add("bg-black", "relative", "z-0");

      // Ensure the video doesn't overflow its container
      this.video.style.width = "100%";
      this.video.style.height = "100%";
      this.video.style.objectFit = "cover";

      console.log("Video display set up successfully");
    } else {
      console.error("Placeholder element not found");
    }

    // Set up capture button
    this.setupCaptureButton();
  },

  setupCaptureButton() {
    // Store reference to capture button for later use
    this.captureBtn = document.querySelector("#capture-photo-btn");
    console.log("Looking for capture button:", this.captureBtn);
    if (this.captureBtn) {
      console.log("Found capture button, setting up click handler");
      this.captureBtn.addEventListener("click", (e) => {
        console.log("Capture button clicked!");
        e.preventDefault();
        this.capturePhoto();
      });
      console.log("Click handler set up successfully");
    } else {
      console.log("Capture button not found!");
    }
  },

  updateCameraStatus(message) {
    const statusElement = document.querySelector("#camera-status");
    if (statusElement) {
      statusElement.textContent = message;
    }
  },

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
    if (this.video) {
      this.video.srcObject = null;
      this.video = null;
    }
  },

  capturePhoto() {
    console.log("capturePhoto called");
    if (!this.video || !this.canvas) {
      console.log("Video or canvas not available");
      return;
    }

    const ctx = this.canvas.getContext("2d");

    // Draw the current video frame to canvas
    ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

    // Convert to base64
    const photoData = this.canvas.toDataURL("image/jpeg", 0.8);

    // Stop the camera stream
    this.stopCamera();

    // Send the photo data to LiveView
    this.pushEvent("photo-captured", { data: photoData });
  },

  destroyed() {
    // Clean up camera stream when component is destroyed
    this.stopCamera();
  },
};

export default CameraCapture;
