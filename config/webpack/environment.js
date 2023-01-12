const { environment } = require("@rails/webpacker");

// Do not transpile react-table as that just doesn't work
const nodeModulesLoader = environment.loaders.get("nodeModules");
if (!Array.isArray(nodeModulesLoader.exclude)) {
  nodeModulesLoader.exclude =
    nodeModulesLoader.exclude == null ? [] : [nodeModulesLoader.exclude];
}
nodeModulesLoader.exclude.push(/react-table/);

try {
  nodeModulesLoader.use[0].options.presets[0][1].modules = "commonjs";
} catch (e) {
  console.warn(
    "Webpack config has changed. Ensure @babel/preset-env modules is still set to commonjs!"
  );
}

module.exports = environment;
