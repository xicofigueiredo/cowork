import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "otherField", "otherInput"]

  connect() {
    this.toggleOther()
  }

  toggleOther() {
    const showOther = this.selectTarget.value === "other"
    this.otherFieldTarget.hidden = !showOther
    this.otherInputTarget.required = showOther

    if (!showOther) {
      this.otherInputTarget.value = ""
    }
  }
}
