/** @import { GaugeChartOptions } from "@carbon/charts" **/
import { GaugeChart, GaugeTypes } from "@carbon/charts";
import { link_host_styles } from "../../utils.js";

/**
 * @typedef {"value" | "height" | "width" | "theme" | "class" } AttributeKeys
 */

export default class Gauge extends HTMLElement {
  /** @type {GaugeChart} */
  #chart;

  /** @type {AttributeKeys[]} */
  static observedAttributes = ["value", "height", "width", "theme", "class"];

  constructor() {
    super();
  }

  connectedCallback() {
    const shadow_root = this.attachShadow({ mode: "closed" });
    const child = document.createElement("div");
    shadow_root.replaceChildren(child);
    link_host_styles(shadow_root);

    const value_text = this.getAttribute("value") ?? "0";
    const height = this.getAttribute("height") ?? undefined;
    const width = this.getAttribute("width") ?? undefined;
    const theme = this.getAttribute("theme") ?? "g90";

    let value_number = Number(value_text);
    value_number = isNaN(value_number) ? 0 : value_number;

    this.#chart = new GaugeChart(child, {
      data: [
        {
          group: "value",
          value: value_number,
        },
      ],
      options: {
        animations: true,
        height: height,
        width: width,
        resizable: true,
        theme: theme,
        color: {
          scale: { value: window.getComputedStyle(this).fill },
        },
        gauge: {
          type: GaugeTypes.SEMI,
          showPercentageSymbol: true,
        },
        toolbar: {
          enabled: false,
        },
      },
    });
  }

  disconnectedCallback() {
    this.#chart?.destroy();
  }

  /**
   * @param {AttributeKeys} name
   * @param {string} old_value
   * @param {string} new_value
   */
  attributeChangedCallback(name, old_value, new_value) {
    if (!this.#chart) return;

    /** @type{GaugeChartOptions} */
    const options = this.#chart.model.getOptions();

    switch (name) {
      case "value": {
        this.#chart.model.setData([
          {
            group: "value",
            value: Number(new_value) ?? 0,
          },
        ]);
        break;
      }
      case "height":
        options.height = new_value;
        break;
      case "width":
        options.width = new_value;
        break;
      case "theme":
        options.theme = new_value;
        break;
      case "class": {
        options.color = {
          ...options.color,
          scale: {
            value: window.getComputedStyle(this).fill,
          },
        };
      }
    }

    this.#chart.update(true);
  }
}

customElements.define("nut-gauge", Gauge);
