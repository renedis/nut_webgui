/** @typedef {"ttl" | "title"  | "closeable" | "type"} AttributeKeys */

const TRIGGER_QUERY =
  ".nut-notification-trigger button, .nut-notification-trigger a, .nut-notification-trigger [role=button]";

export default class NutNotification extends HTMLElement {
  /** @type {number|undefined} */
  #timer;

  constructor() {
    super();
    this.#timer = undefined;
  }

  connectedCallback() {
    const ttl_attr = Number(this.getAttribute("ttl"));
    const type = this.getAttribute("type") ?? "info";
    const ttl = isNaN(ttl_attr) || ttl_attr < 1 ? 3000 : ttl_attr;
    const dismissElements = this.querySelectorAll(TRIGGER_QUERY);

    for (const element of dismissElements) {
      element.addEventListener("click", () => this?.remove());
    }

    this.className = `${this.className} alert alert-${type}`;
    this.#timer = setTimeout(() => {
      this?.remove();
    }, ttl);
  }

  disconnectedCallback() {
    if (this.#timer) {
      clearTimeout(this.#timer);
    }

    this.remove();
  }

  dismiss() {
    this.remove();
  }

  /** @param {string} id */
  static dismiss(id) {
    /** @type {UpsMonNotification} */
    const element = document.getElementById(id);
    if (element) {
      element?.dismiss();
    } else {
      console.warn(`${id} does not exists in document.`);
    }
  }
}

customElements.define("nut-notification", NutNotification);
Reflect.set(window, "NutNotification", NutNotification);
