await Bun.build({
  entrypoints: ['./app/javascript/action_cable/index.js'],
  outdir: './app/assets/javascripts/',
  naming: "chronocable.[ext]",
  target: 'browser',
  format: "esm",
})

await Bun.build({
  entrypoints: ["./app/javascript/turbo/index.js"],
  outdir: "./app/assets/javascripts/",
  naming: "chronocable_turbo.js",
  target: "browser",
  format: "esm"
})

await Bun.build({
  entrypoints: ["./app/javascript/turbo/index.js"],
  outdir: "./app/assets/javascripts/",
  naming: "chronocable_turbo.min.js",
  target: "browser",
  format: "esm",
  minify: true,
})
