const CameraCapture = {
  mounted() {
    console.log("CameraCapture hook mounted");
    this.stream = null;
    this.video = null;
    this.canvas = null;

    // Listen for the scan-card event from the dashboard
    this.handleEvent("scan-card", () => {
      console.log("Scan card event received, starting camera...");
      this.startCamera();
    });
  },

  async startCamera() {
    console.log("Starting camera...");
    try {
      // Request camera access
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "environment", // Use back camera on mobile
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });
      console.log("Camera access granted");

      // Create video element
      this.video = document.createElement("video");
      this.video.srcObject = this.stream;
      this.video.autoplay = true;
      this.video.playsInline = true;

      // Create canvas for capturing
      this.canvas = document.createElement("canvas");
      this.canvas.width = 1280;
      this.canvas.height = 720;
      const ctx = this.canvas.getContext("2d");

      // Wait for video to be ready
      this.video.addEventListener("loadedmetadata", () => {
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
        }

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
      });
    } catch (error) {
      console.error("Error accessing camera:", error);
      alert("Unable to access camera. Please check permissions and try again.");
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
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
    }

    // Send the photo data to LiveView
    this.pushEvent("photo-captured", { data: photoData });
  },

  destroyed() {
    // Clean up camera stream when component is destroyed
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
    }
  },
};

export default CameraCapture;
