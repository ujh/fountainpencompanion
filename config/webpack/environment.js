const { environment } = require("@rails/webpacker");

// Do not transpile react-table as that just doesn't work
const nodeModulesLoader = environment.loaders.get("nodeModules");
if (!Array.isArray(nodeModulesLoader.exclude)) {
  nodeModulesLoader.exclude =
    nodeModulesLoader.exclude == null ? [] : [nodeModulesLoader.exclude];
}
nodeModulesLoader.exclude.push(/react-table/);

module.exports = environment;
