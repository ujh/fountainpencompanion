const { environment } = require("@rails/webpacker");

// Do not transpile react-table as that just doesn't work
const nodeModulesLoader = environment.loaders.get("nodeModules");
if (!Array.isArray(nodeModulesLoader.exclude)) {
  nodeModulesLoader.exclude =
    nodeModulesLoader.exclude == null ? [] : [nodeModulesLoader.exclude];
}
nodeModulesLoader.exclude.push(/react-table/);

/*
 * This makes recharts 2 work, it then however makes other parts of the code fail to load.
 */
// try {
//   nodeModulesLoader.use[0].options.presets[0][1].modules = "commonjs";
// } catch (e) {
//   console.warn(
//     "Webpack config has changed. Ensure @babel/preset-env modules is still set to commonjs!"
//   );
// }

module.exports = environment;
