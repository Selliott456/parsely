const CameraCapture = {
  mounted() {
    console.log("CameraCapture hook mounted");
    this.stream = null;
    this.video = null;
    this.canvas = null;
    this.metadataTimer = null;

    // Always reinitialize on page visit to avoid stale black video on return

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

    // Set up capture button immediately
    this.setupCaptureButton();

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
      // Do not persist globally; we want clean init when page is revisited
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
      this.video.muted = true; // allow autoplay on mobile
      window.__parsely_camera_video = this.video;

      // Attach video to placeholder immediately so user sees something
      this.attachVideoPlaceholder();

      // Create canvas for capturing
      this.canvas = document.createElement("canvas");
      this.canvas.width = 1280;
      this.canvas.height = 720;

      // Start playback, handle promise
      try {
        await this.video.play();
        console.log("Video playback started");
      } catch (playErr) {
        console.warn("Autoplay failed, waiting for metadata:", playErr);
      }

      // Wait for video to be ready, with fallback timeout
      const onReady = () => {
        clearTimeout(this.metadataTimer);
        console.log("Video metadata loaded, setting up video display");
        console.log(
          "Video dimensions:",
          this.video.videoWidth,
          "x",
          this.video.videoHeight
        );
        this.updateCameraStatus("Camera ready");
        this.setupVideoDisplay();
      };

      this.video.addEventListener("loadedmetadata", onReady, { once: true });
      this.video.addEventListener("loadeddata", onReady, { once: true });

      this.metadataTimer = setTimeout(() => {
        console.warn("Video metadata timeout; proceeding to setup display");
        this.updateCameraStatus("Camera ready");
        this.setupVideoDisplay();
      }, 5000);

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
    const placeholder =
      document.querySelector("#camera-container") ||
      document.querySelector(".bg-zinc-100, .camera-placeholder");
    if (placeholder) {
      // If already prepared, avoid reflow/flicker
      if (placeholder.classList.contains("camera-ready")) {
        return;
      }
      // Ensure a stable inner wrapper to preserve height
      let holder = placeholder.querySelector(".camera-holder");
      if (!holder) {
        holder = document.createElement("div");
        holder.className = "camera-holder w-full h-full";
        // Clear only the dynamic part
        while (placeholder.firstChild)
          placeholder.removeChild(placeholder.firstChild);
        placeholder.appendChild(holder);
      }
      holder.innerHTML = "";
      holder.appendChild(this.video);
      placeholder.classList.remove("bg-zinc-100");
      placeholder.classList.add(
        "bg-black",
        "relative",
        "z-0",
        "camera-placeholder",
        "camera-ready"
      );

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

    // Double-check that the button is properly set up
    setTimeout(() => {
      const btn = document.querySelector("#capture-photo-btn");
      console.log("Final button check:", btn);
      if (btn) {
        console.log("Button is in DOM and ready");
      } else {
        console.error("Button still not found after setup!");
      }
    }, 200);
  },

  attachVideoPlaceholder() {
    // Ensures there's a container to hold the video immediately
    const container =
      document.querySelector("#camera-container") ||
      document.querySelector(".bg-zinc-100");
    if (container) {
      container.classList.add("camera-placeholder");
      let holder = container.querySelector(".camera-holder");
      if (!holder) {
        holder = document.createElement("div");
        holder.className = "camera-holder w-full h-full";
        // Clear only the dynamic part
        while (container.firstChild)
          container.removeChild(container.firstChild);
        container.appendChild(holder);
      }
      holder.innerHTML = "";
      holder.appendChild(this.video);
      // Apply final sizing immediately to avoid initial small frame
      container.classList.remove("bg-zinc-100");
      container.classList.add("bg-black", "relative", "z-0", "camera-ready");
      this.video.style.width = "100%";
      this.video.style.height = "100%";
      this.video.style.objectFit = "cover";
      this.updateCameraStatus("Starting camera...");
    }
  },

  setupCaptureButton() {
    // Store reference to capture button for later use
    this.captureBtn = document.querySelector("#capture-photo-btn");
    console.log("Looking for capture button:", this.captureBtn);
    if (this.captureBtn) {
      console.log("Found capture button, setting up click handler");
      // Remove any existing event listeners to avoid duplicates
      this.captureBtn.removeEventListener("click", this.capturePhotoHandler);
      this.capturePhotoHandler = (e) => {
        console.log("Capture button clicked!");
        e.preventDefault();
        this.capturePhoto();
      };
      this.captureBtn.addEventListener("click", this.capturePhotoHandler);
      console.log("Click handler set up successfully");
    } else {
      console.log("Capture button not found!");
      // Retry after a short delay in case the DOM hasn't updated yet
      setTimeout(() => {
        this.setupCaptureButton();
      }, 100);
    }
  },

  updateCameraStatus(message) {
    const statusElement = document.querySelector("#camera-status");
    if (statusElement) {
      statusElement.textContent = message;
    }
  },

  stopCamera() {
    clearTimeout(this.metadataTimer);
    if (this.stream) {
      try {
        this.stream.getTracks().forEach((track) => track.stop());
      } catch (_) {}
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
    clearTimeout(this.metadataTimer);
    this.stopCamera();

    // Clean up event listeners
    if (this.captureBtn && this.capturePhotoHandler) {
      this.captureBtn.removeEventListener("click", this.capturePhotoHandler);
    }

    delete window.__parsely_camera_stream;
    delete window.__parsely_camera_video;
  },
};

export default CameraCapture;
