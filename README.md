# Envelope

Personal budget application for the Elementary OS desktop. It
is written in Vala and uses the [Granite](https://launchpad.net/granite) framework.

http://nlaplante.github.io/envelope

[![Build Status](https://travis-ci.org/nlaplante/envelope.svg)](https://travis-ci.org/nlaplante/envelope)

## Introduction

Envelope helps you maintain your personal budget by using the tried-and-true [envelope system](https://en.wikipedia.org/wiki/Envelope_system). You designate spending categories (envelopes) and distribute your monthly income into them.

Envelope lets you configure accounts where you record all your transactions. You then assign each of them to a category.

In Elementary OS, Envelope is known as *Budget*.

## Features

* Envelope system budget workflow
* Import transactions from QIF/OFX files
* Integrates with the Elementary OS desktop

## Installation

### Elementary OS

Envelope is available as a daily build package in **ppa:nicolas-laplante/envelope-daily**. Just add the ppa and install envelope like this:

```sh
$ sudo add-apt-repository ppa:nicolas-laplante/envelope-daily
$ sudo apt-get update
$ sudo apt-get install envelope
```

### Other systems

There ain't no binary package distribution except for Elementary OS yet. To use Envelope now, you'll have to build it from sources.

#### Dependencies
* cmake
* Vala >=0.23.2
* glib >=2.29.0
* gio-2.0
* Gtk+ >=3.10
* libgee-0.8
* granite-0.3
* sqlheavy-0.1

#### Building from sources
```sh
$ git clone https://github.com/nlaplante/envelope
$ cd envelope
$ mkdir build
$ cd build
$ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Debug ..
$ make
```
From there you can either use the binary in `build/src/envelope` or install it:
```sh
$ sudo make install
```

You can also run the unit tests:
```sh
$ tests/envelope-tests
```

## Contributing

Want to help? Just fork this repository, pick an issue and start hacking. Just follow the coding style and document your changes.

### Commit messages

Commit messages should follow the [AngularJS commit message conventions](https://docs.google.com/document/d/1QrDFcIiPjSLDn3EL15IJygNPiHORgU1_OOAqWjiDU5Y/edit),
since the changelog is generated from the commit history.
