import Hls from "hls.js";
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["audio", "video"];

  /*
  :::::::::::::::
  :: Lifecycle ::
  :::::::::::::::
  */
  connect() {
    const hlsSupported = Hls.isSupported();
    const nativeHlsSupport = this.videoTarget.canPlayType(
      "application/vnd.apple.mpegurl"
    );
    const streamUrl = this.data.get("streamUrl");
    const fallbackUrl = this.data.get("fallbackUrl");

    if (hlsSupported) {
      this.hls = new Hls();
      this.hls.attachMedia(this.videoTarget);
      this.hls.on(Hls.Events.MEDIA_ATTACHED, () => {
        this.hls.loadSource(streamUrl);
      });
      this.videoTarget.style.setProperty("display", "block");
      this.audioTarget.style.setProperty("display", "none");
    } else if (nativeHlsSupport) {
      this.player.setAttribute("src", streamUrl);
      this.videoTarget.style.setProperty("display", "block");
      this.audioTarget.style.setProperty("display", "none");
    } else {
      this.player.setAttribute("src", fallbackUrl);
      this.audioTarget.style.setProperty("display", "block");
      this.videoTarget.style.setProperty("display", "none");
    }
  }
}
