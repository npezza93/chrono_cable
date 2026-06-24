await Bun.build({
  entrypoints: ['./app/javascript/action_cable/index.js'],
  outdir: './app/assets/javascripts/',
  naming: "actioncable.[ext]",
  target: 'browser',
  format: "esm",
})
