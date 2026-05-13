#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

node - "$repo_dir/src/qml/util.js" <<'NODE'
const fs = require('fs');
const vm = require('vm');

const utilPath = process.argv[2];
const source = fs.readFileSync(utilPath, 'utf8').replace(/^\s*\.pragma library\s*$/m, '');
const context = {
  console: { log() {} },
  Qt: {
    application: {},
    createQmlObject() {
      return {
        createObject() {
          return {
            triggered: { connect() {}, disconnect() {} },
            start() {},
            stop() {},
            repeat: false
          };
        }
      };
    },
    point(x, y) {
      return { x, y };
    }
  }
};

vm.createContext(context);
vm.runInContext(source, context, { filename: utilPath });

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    console.error(`${label}: got ${JSON.stringify(actual)}, wanted ${JSON.stringify(expected)}`);
    process.exit(1);
  }
}

function assert(condition, label) {
  if (!condition) {
    console.error(label);
    process.exit(1);
  }
}

assertEqual(context.decodeHtml('&lt;3 &amp; &#039; &apos; &#x27;'),
            "<3 & ' ' '",
            'decodeHtml decodes named and numeric entities');
assertEqual(context.decodeHtml('left &unknown; right'),
            'left &unknown; right',
            'decodeHtml preserves unknown entities');
assertEqual(context.decodeHtml('left &unterminated'),
            'left &unterminated',
            'decodeHtml preserves unterminated entities');

assertEqual(context.makeUrl('twitch.tv'),
            '<a href="https://twitch.tv">twitch.tv</a>',
            'makeUrl defaults bare domains to HTTPS');
assertEqual(context.makeUrl('www.example.org/path'),
            '<a href="https://www.example.org/path">www.example.org/path</a>',
            'makeUrl defaults www domains to HTTPS');
assertEqual(context.makeUrl('http://example.com'),
            '<a href="http://example.com">http://example.com</a>',
            'makeUrl preserves explicit HTTP URLs');
assertEqual(context.makeUrl('this.is.not.a.url'),
            'this.is.not.a.url',
            'makeUrl preserves likely false positives');

assert(context.regexContainsHtmlEntity('(?:foo|&lt;3)'), 'regexContainsHtmlEntity scans alternatives');
assert(context.regexContainsHtmlEntity('foo&#60;bar'), 'regexContainsHtmlEntity detects decimal entities');
assert(context.regexContainsHtmlEntity('foo&#x3c;bar'), 'regexContainsHtmlEntity detects hex entities');
assert(!context.regexContainsHtmlEntity('Fish&chips'), 'regexContainsHtmlEntity ignores raw ampersands');
NODE
