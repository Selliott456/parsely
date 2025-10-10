// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import PhotoCapture from "./hooks/photo_capture";
import PasswordStrength from "./hooks/password_strength";
import CameraCapture from "./hooks/camera_capture";

const Hooks = {
  AutoDismissFlash: {
    mounted() {
      const ms = parseInt(this.el.dataset.autodismiss || "4000", 10);
      const key = this.el.dataset.key;
      if (!isNaN(ms) && ms > 0) {
        this.timer = setTimeout(() => {
          // Push clear-flash to server, then hide element
          this.pushEvent("lv:clear-flash", { key });
          this.el.style.transition = "opacity 200ms ease";
          this.el.style.opacity = "0";
          setTimeout(() => this.el.remove(), 220);
        }, ms);
      }
    },
    destroyed() {
      if (this.timer) clearTimeout(this.timer);
    },
  },
  LocaleCookie: {
    mounted() {
      this.handleEvent("set-locale-cookie", ({ locale }) => {
        try {
          const value = locale === "ja" ? "ja" : "en";
          document.cookie = `locale=${value}; Path=/; Max-Age=${
            60 * 60 * 24 * 365
          }`;
        } catch (e) {
          console.warn("Failed to set locale cookie", e);
        }
      });
    },
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { PhotoCapture, PasswordStrength, CameraCapture, ...Hooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
