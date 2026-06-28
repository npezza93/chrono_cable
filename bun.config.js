await Bun.build({
  entrypoints: ['./app/javascript/action_cable/index.js'],
  outdir: './app/assets/javascripts/',
  naming: "chronocable.[ext]",
  target: 'browser',
  format: "esm",
})
