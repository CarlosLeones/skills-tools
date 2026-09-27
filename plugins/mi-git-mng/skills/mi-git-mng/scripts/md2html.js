#!/usr/bin/env node
// md2html.js — convierte el informe .md en un .html autocontenido que renderiza el
// Markdown y los diagramas Mermaid en el navegador.
//
// Uso: node md2html.js <entrada.md> <salida.html> [titulo]
//
// El HTML carga marked y mermaid (versiones fijas) desde cdn.jsdelivr.net; no necesita
// instalar nada. El Markdown va embebido tal cual, asi que el .md sigue siendo la fuente.

const fs = require("fs");
const path = require("path");

const [, , input, output, titleArg] = process.argv;
if (!input || !output) {
  console.error("Uso: node md2html.js <entrada.md> <salida.html> [titulo]");
  process.exit(1);
}

const md = fs.readFileSync(input, "utf8").replace(/^﻿/, "");
const title =
  titleArg ||
  (md.match(/^#\s+(.+)$/m) || [])[1] ||
  path.basename(input, path.extname(input));

const template = fs.readFileSync(
  path.join(__dirname, "..", "assets", "actions-template.html"),
  "utf8"
);

const escapeHtml = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// El Markdown va dentro de <script type="text/markdown">: solo hay que evitar que
// cierre la etiqueta antes de tiempo.
const embedded = md.replace(/<\/script/gi, "<\\/script");

const html = template
  .replace(/__TITLE__/g, escapeHtml(title))
  .replace("__MARKDOWN__", () => embedded);

fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
fs.writeFileSync(output, html);
console.log(`HTML generado: ${output}`);
