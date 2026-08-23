import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "menu"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    this.removeListeners()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    this.menuTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("keydown", this.handleKeydown)
  }

  closeMenu() {
    this.menuTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.removeListeners()
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.closeMenu()
      this.toggleTarget.focus()
    }
  }

  isOpen() {
    return !this.menuTarget.hidden
  }

  removeListeners() {
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("keydown", this.handleKeydown)
  }
}
