const PhotoCapture = {
  mounted() {
    this.input = this.el;
    this.input.addEventListener("change", this.handleFileSelect.bind(this));
  },

  handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    // Check if it's an image
    if (!file.type.startsWith("image/")) {
      console.error("Selected file is not an image");
      return;
    }

    // Convert to base64 for preview
    const reader = new FileReader();
    reader.onload = (e) => {
      const base64Data = e.target.result;

      // Push the photo data to the LiveView
      this.pushEvent("photo-captured", { data: base64Data });
    };

    reader.readAsDataURL(file);
  },

  destroyed() {
    if (this.input) {
      this.input.removeEventListener(
        "change",
        this.handleFileSelect.bind(this)
      );
    }
  },
};

export default PhotoCapture;
