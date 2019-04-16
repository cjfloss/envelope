<div>
  <h1 align="center">Envelope</h1>
  <h3 align="center">Personal budget manager</h3>
  <p align="center">Designed for <a href="https://elementary.io"> elementary OS</p>
</div>
<p align="center">
  <a href="https://appcenter.elementary.io/com.github.cjfloss.envelope">
    <img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter">
  </a>
</p>
<p align="center">
  <img src="data/screenshots/05.png" alt="screenshot" />
</p>

[![Build Status](https://travis-ci.com/cjfloss/envelope.svg?branch=master)](https://travis-ci.com/cjfloss/envelope)

## Introduction

Envelope helps you maintain your personal budget by using the tried-and-true [envelope system](https://en.wikipedia.org/wiki/Envelope_system).

Designate spending categories (envelopes) and distribute your monthly income into them.

Configure accounts where you record all your transactions, then assign each of them to a category.

## Features

* Envelope system budget workflow
* Import transactions from QIF files

## Installation

#### Dependencies
* meson
* ninja
* Vala >=0.23.2
* glib >=2.30
* gio-2.0
* Gtk+ >=3.14
* libgee-0.8
* granite-0.3
* sqlite3

#### Building from sources
```sh
$ git clone https://github.com/cjfloss/envelope.git
$ meson envelope build
$ ninja -C build
```
From there you can either use the binary in `build/src/com.github.cjfloss.envelope` or install it:
```sh
$ sudo ninja -C build install
```

## Contributing

Want to help? Just fork this repository, pick an issue and start hacking. Just follow the coding style and document your changes.

### Commit messages

Commit messages should follow the [AngularJS commit message conventions](https://docs.google.com/document/d/1QrDFcIiPjSLDn3EL15IJygNPiHORgU1_OOAqWjiDU5Y/edit),
since the changelog is generated from the commit history.
