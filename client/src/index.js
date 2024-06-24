/**
 * Main entry point for client
 * Exports all web components, registers dom load events.
 */

import htmx from "htmx.org/dist/htmx.esm.js";
import { Idiomorph } from "idiomorph/dist/idiomorph.esm.js";

export * from "./components/charts/gauge.js";
export * from "./components/notification.js";
export * from "./components/confirmation_modal.js";
export * from "./components/theme_selector.js";

/**
 * @param {string} attr_name
 * @param {Element} node
 * @param {"updated" | "removed"} mutation_type
 * @returns {boolean}
 */
function attr_preserve(attr_name, node, mutation_type) {
  const preserve = node.getAttribute("morph-preserve-attr");

  if (preserve) {
    const target_attrs = preserve.split(" ");
    return !(target_attrs.findIndex((e) => e === attr_name) > -1);
  } else {
    return true;
  }
}

function create_morph_config(swapStyle) {
  let config;
  if (swapStyle === "morph" || swapStyle === "morph:outerHTML") {
    config = { morphStyle: "outerHTML" };
  } else if (swapStyle === "morph:innerHTML") {
    config = { morphStyle: "innerHTML" };
  } else if (swapStyle.startsWith("morph:")) {
    config = Function("return (" + swapStyle.slice(6) + ")")();
  }

  config.callbacks = { beforeAttributeUpdated: attr_preserve };

  return config;
}

htmx.defineExtension("morph", {
  isInlineSwap: function (swapStyle) {
    const config = create_morph_config(swapStyle);
    return config.swapStyle === "outerHTML" || config.swapStyle == null;
  },
  handleSwap: function (swapStyle, target, fragment) {
    const config = create_morph_config(swapStyle);

    if (config) {
      return Idiomorph.morph(target, fragment.children, config);
    }
  },
});
