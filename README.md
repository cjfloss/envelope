<div>
    <h1 align="center">Envelope</h1>
    <p align="center">
        <img src="https://raw.githubusercontent.com/cjfloss/envelope/master/data/screenshots/05.png" alt="screenshot">
    </p>
    <h2 align="center">Personal budget application for the elementary OS desktop</h2>
</div>

[![Build Status](https://travis-ci.org/cjfloss/envelope.svg)](https://travis-ci.org/cjfloss/envelope)

## Introduction

Envelope helps you maintain your personal budget by using the tried-and-true [envelope system](https://en.wikipedia.org/wiki/Envelope_system).
You designate spending categories (envelopes) and distribute your monthly income into them.

Envelope lets you configure accounts where you record all your transactions. You then assign each of them to a category.

## Features

* Envelope system budget workflow
* Import transactions from QIF/OFX files
* Integrates with the elementary OS desktop

## Installation

#### Dependencies
* meson
* ninja
* Vala >=0.23.2
* glib >=2.29.0
* gio-2.0
* Gtk+ >=3.10
* libgee-0.8
* granite-0.3
* sqlheavy-0.1

#### Building from sources
```sh
$ git clone https://github.com/cjfloss/envelope.git
$ cd envelope
$ meson build && cd build
$ ninja
```
From there you can either use the binary in `src/com.github.cjfloss.envelope` or install it:
```sh
$ sudo ninja install
```

## Contributing

Want to help? Just fork this repository, pick an issue and start hacking. Just follow the coding style and document your changes.

### Commit messages

Commit messages should follow the [AngularJS commit message conventions](https://docs.google.com/document/d/1QrDFcIiPjSLDn3EL15IJygNPiHORgU1_OOAqWjiDU5Y/edit),
since the changelog is generated from the commit history.
