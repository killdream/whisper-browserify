# Whisper: Browserify [![Build Status](https://travis-ci.org/killdream/whisper-browserify.png)](https://travis-ci.org/killdream/whisper-browserify)

Compiles CommonJS modules with Browserify.


### Example

Define a list of files that should be fed to browserify, and the destination of
the bundles in your `.whisper` file:

```js
module.exports = function(whisper) {
  whisper.configure({
    browserify: {
      files: ['lib/*.js'],
      dest: ['browser/'],
      debugging: true
    }
  })
  
  require('whisper-browserify')(whisper)
}
```

And invoke the `whisper browserify` task on your project to compile the files:

```bash
$ whisper browserify
```


### Installing

Just grab it from NPM:

    $ npm install whisper-browserify


### Documentation

Just invoke `whisper help browserify` to show the manual page for the
`browserify` task.


### Licence

MIT/X11. ie.: do whatever you want.

[es5-shim]: https://github.com/kriskowal/es5-shim
