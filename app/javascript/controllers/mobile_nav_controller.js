import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.element.classList.add("landing-top--nav-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.element.classList.remove("landing-top--nav-open")
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", "false")
    }
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close()
      this.toggleTarget.focus()
    }
  }

  isOpen() {
    return this.element.classList.contains("landing-top--nav-open")
  }
}
