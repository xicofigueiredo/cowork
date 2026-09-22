import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["periodFields", "fromInput", "toInput"]

  connect() {
    this.sync()
  }

  sync() {
    const permanent = this.element.querySelector('select[name="validity_type"]')?.value === "permanent"

    this.periodFieldsTargets.forEach((el) => {
      el.hidden = permanent
    })

    ;[this.fromInputTarget, this.toInputTarget].forEach((input) => {
      input.required = !permanent
      input.disabled = permanent
    })
  }
}
