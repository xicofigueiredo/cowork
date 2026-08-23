import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "mezzanine_cookie_consent"

export default class extends Controller {
  connect() {
    const consent = localStorage.getItem(STORAGE_KEY)

    if (consent === "accepted") {
      this.hide()
      this.enableThirdParty()
    } else if (consent === "rejected") {
      this.hide()
    } else {
      this.element.hidden = false
    }
  }

  accept() {
    localStorage.setItem(STORAGE_KEY, "accepted")
    this.hide()
    this.enableThirdParty()
  }

  reject() {
    localStorage.setItem(STORAGE_KEY, "rejected")
    this.hide()
  }

  hide() {
    this.element.hidden = true
  }

  enableThirdParty() {
    document.querySelectorAll("[data-requires-consent]").forEach((element) => {
      const src = element.dataset.src
      if (src && !element.getAttribute("src")) {
        element.setAttribute("src", src)
      }
      element.hidden = false
    })

    document.querySelectorAll("[data-consent-placeholder]").forEach((element) => {
      element.hidden = true
    })
  }
}
