const PasswordStrength = {
  mounted() {
    this.passwordInput = this.el;
    this.confirmInput = document.querySelector(
      'input[name="user[password_confirmation]"]'
    );

    this.passwordInput.addEventListener(
      "input",
      this.checkPasswordStrength.bind(this)
    );
    if (this.confirmInput) {
      this.confirmInput.addEventListener(
        "input",
        this.checkPasswordMatch.bind(this)
      );
    }
  },

  checkPasswordStrength(event) {
    const password = event.target.value;
    const strength = this.calculateStrength(password);
    this.updateStrengthIndicator(strength);
    this.checkPasswordMatch();
  },

  checkPasswordMatch() {
    if (!this.confirmInput) return;

    const password = this.passwordInput.value;
    const confirmPassword = this.confirmInput.value;

    if (confirmPassword && password !== confirmPassword) {
      this.confirmInput.classList.add("border-red-500");
      this.confirmInput.classList.remove("border-zinc-300", "border-zinc-400");
    } else {
      this.confirmInput.classList.remove("border-red-500");
      this.confirmInput.classList.add("border-zinc-300");
    }
  },

  calculateStrength(password) {
    let score = 0;
    const feedback = [];

    if (password.length >= 12) score += 1;
    else feedback.push("At least 12 characters");

    if (/[a-z]/.test(password)) score += 1;
    else feedback.push("One lowercase letter");

    if (/[A-Z]/.test(password)) score += 1;
    else feedback.push("One uppercase letter");

    if (/[0-9]/.test(password)) score += 1;
    else feedback.push("One number");

    if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) score += 1;
    else feedback.push("One special character");

    return { score, feedback };
  },

  updateStrengthIndicator(strength) {
    // Remove existing indicator
    const existingIndicator = document.getElementById("password-strength");
    if (existingIndicator) {
      existingIndicator.remove();
    }

    if (!this.passwordInput.value) return;

    const indicator = document.createElement("div");
    indicator.id = "password-strength";
    indicator.className = "mt-2 text-sm";

    const strengthText = ["Very Weak", "Weak", "Fair", "Good", "Strong"];
    const strengthColors = [
      "text-red-600",
      "text-orange-600",
      "text-yellow-600",
      "text-blue-600",
      "text-green-600",
    ];
    const bgColors = [
      "bg-red-100",
      "bg-orange-100",
      "bg-yellow-100",
      "bg-blue-100",
      "bg-green-100",
    ];

    indicator.innerHTML = `
      <div class="flex items-center gap-2">
        <span class="font-medium ${
          strengthColors[strength.score - 1] || "text-gray-600"
        }">
          ${strengthText[strength.score - 1] || "Very Weak"}
        </span>
        <div class="flex-1 bg-gray-200 rounded-full h-2">
          <div class="h-2 rounded-full ${
            bgColors[strength.score - 1] || "bg-gray-300"
          }"
               style="width: ${(strength.score / 5) * 100}%"></div>
        </div>
      </div>
      ${
        strength.feedback.length > 0
          ? `
        <div class="mt-1 text-xs text-gray-600">
          <p class="font-medium">Requirements:</p>
          <ul class="list-disc list-inside">
            ${strength.feedback.map((f) => `<li>${f}</li>`).join("")}
          </ul>
        </div>
      `
          : ""
      }
    `;

    this.passwordInput.parentNode.appendChild(indicator);
  },

  destroyed() {
    if (this.passwordInput) {
      this.passwordInput.removeEventListener(
        "input",
        this.checkPasswordStrength.bind(this)
      );
    }
    if (this.confirmInput) {
      this.confirmInput.removeEventListener(
        "input",
        this.checkPasswordMatch.bind(this)
      );
    }
  },
};

export default PasswordStrength;
