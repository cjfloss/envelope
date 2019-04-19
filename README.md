# Envelope [![Build Status](https://travis-ci.com/cjfloss/envelope.svg?branch=master)](https://travis-ci.com/cjfloss/envelope)
### Personal budget manager
![Screenshot](https://github.com/cjfloss/envelope/raw/master/data/screenshots/03.png)
Envelope helps you maintain your personal budget by using the tried-and-true [envelope system](https://en.wikipedia.org/wiki/Envelope_system).  
Designate spending categories (envelopes) and distribute your monthly income into them.  
Configure accounts where you record all your transactions, then assign each of them to a category.  

* Envelope system budget workflow
* Import transactions from QIF files

## Installation
[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.cjfloss.envelope)

### Dependencies
These dependencies must be present before building
- `meson`
- `ninja-build`
- `Vala`
- `GLib`
- `gio-2.0`
- `GTK`
- `libgee-0.8`
- `Granite`
- `SQlite3`

 **You can install these on a Ubuntu-based system by executing this command:**

`sudo apt install meson ninja-build valac libgtk-3-dev libgee-0.8-dev libgranite-dev libsqlite3-dev ` 

### Building
```
$ git clone https://github.com/cjfloss/envelope.git
$ meson envelope build
$ ninja -C build
```

### Installing & executing
```
$ sudo ninja -C build install
$ com.github.cjfloss.envelope
```

## Contributing

Want to help? Just fork this repository, pick an issue and start hacking. Just follow the [elementary coding style](https://elementary.io/docs/code/reference#code-style) and document your changes.

### Commit messages

Commit messages should follow the [AngularJS commit message conventions](https://docs.google.com/document/d/1QrDFcIiPjSLDn3EL15IJygNPiHORgU1_OOAqWjiDU5Y/edit)
