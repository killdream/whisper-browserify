## Module whisper-browserify
#
# Compiles CommonJS modules with Browserify.
#
#
# Copyright (c) 2013 Quildreen "Sorella" Motta <quildreen@gmail.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module.exports = (whisper) ->

  ### -- Dependencies --------------------------------------------------
  fs               = require 'fs'
  browserify       = require 'browserify'
  glob             = (require 'glob').sync
  {merge, Promise} = (require 'cassie')

  { concat-map, unique } = require 'prelude-ls'

  ### -- Helpers -------------------------------------------------------

  #### λ expand
  # Returns a list of files that match a list of glob patterns.
  #
  # :: [String] -> [String]
  expand = (xs or []) -> (unique . (concat-map glob)) xs

  #### λ callable-p
  # Checks if something can be called.
  #
  # :: a -> Bool
  callable-p = (a) -> typeof a is 'function'

  #### λ display-transform
  # Displays transform information.
  #
  # :: [String] -> String
  display-transform = (transform or []) ->
    | transform.length is 0 => ''
    | otherwise             => "| #transform"

  #### λ display-requires
  # Displays requires information.
  #
  # :: [String] -> String
  display-requires = (reqs or [], exts or []) ->
    | reqs.length > 0 and exts.length > 0 => ", requiring #reqs and #exts"
    | reqs.length > 0 => ", requiring #reqs"
    | exts.length > 0 => ", requiring external #exts"
    | otherwise       => ''

  #### λ display-ignores
  # Displays ignores information.
  #
  # :: [String] -> String
  display-ignores = (xs or []) ->
    | xs.length > 0 => ", ignoring #xs"
    | otherwise     => ''

  #### λ display
  # Shows Bundle info in a human-readable way.
  #
  # :: Bundle -> String
  display = (options) ->
    "(Bundle #{options.entry or ''} #{display-transform options.trasnform} -> #{options.output})
    #{display-requires options.require, options.external}
    #{display-ignores options.ignores}.

    { globals: #{options.globals or 'detect-globals'}, debug: #{options.debug or false} }"

  #### λ transform
  # Applies the given transformation to the bundle.
  #
  # :: Browserify -> String | Function -> ()
  transform = (bundle, module) -->
    | callable-p module => bundle.transform module
    | otherwise         => (glob module).for-each (-> bundle.transform it)

  #### λ build-bundle
  # Generates a browserify bundle from an Bundle object.
  #
  # :: Bundle -> Promise String
  build-bundle = (options) ->
    p = Promise.make!
    bundle = browserify ...(expand options.entry)
    (expand options.[]require).for-each  (-> bundle.require it)
    (expand options.[]external).for-each (-> bundle.external it)
    (expand options.[]ignore).for-each   (-> bundle.ignore it)
    options.[]transform.for-each (transform bundle)

    bundle-opts =
      debug: options.debug
      insert-globals: options.globals is \insert-globals
      detect-globals: options.globals is \detect-globals

    bundle.bundle bundle-opts, (err, src) ->
      | err => do
               whisper.log.error "Failed to generate a bundle for #{display options}.\n #err"
               p.fail err
      | _   => do
               whisper.log.info "Bundle generated successfully for #{display options}."
               fs.write-file-sync options.output, src
               p.bind src

    p


  ### -- Tasks ---------------------------------------------------------
  whisper.task 'browserify'
             , []
             , """Compiles CommonJS modules with Browserify.

               This task will generate Browserify bundles from the
               CommonJS modules in your project. We accept a list of
               `Bundle` options with different definitions.

               Options passed to the `browserify` task in your
               `.whisper` file should conform to the following
               structure:

                   type Browserify : [Bundle]

                   type Bundle : {
                     output: String

                     entry: [String]
                     require: [GlobPattern]
                     external: [GlobPattern]

                     ignore: [GlobPattern]
                     transform: [String | Function]

                     globals: GlobalMode
                     debug: Boolean
                   }

                   type GlobalMode : insert-globals
                                   | detect-globals


               ## Options

               - `output` (required): The path where the bundle will end
                 up.

               - `entry`: One or more files that act as the entry-point
                 of the application. These will be required by default
                 after being defined.

               - `require`: One or more modules to make available in the
                 bundle through `require` calls.

               - `external`: Allows referencing external files in other
                 Browserify bundles. Useful if you're splitting your
                 bundles in several parts to take advantage of caching.

               - `ignore`: A list of modules to ignore when analysing
                 the dependencies.

               - `transform`: A list of modules that implement the
                 `transform` interface for Browserify, and act upon
                 top-level files for transforming the source code in
                 some way — for example, to provide automatic
                 compilation of CoffeeScript.

               - `globals`: Defines the way Browserify handles globals,
                 can be either `insert-globals`, to handle them the fast
                 but inefficient way, costing you some extra bytes. Or
                 `detect-globals`, to analyse the files and insert those
                 variables only if necessary, saving you some bytes, but
                 slowing down the build process.

               - `debug`: Enable source-maps to allow debugging of
                 modules separately. Useful in development mode!


               ## Example

               A common use case would be to generate a single bundle
               from the main file in your package. In this case, you can
               just use `./` to resolve to the main file defined in your
               `package.json`:

                   module.exports = function(whisper) {
                     whisper.configure({
                       browserify: {
                         output: 'browser/all.js',
                         entry: ['./']
                       }
                     })

                     require('whisper-browserify')(whisper)
                   }

               ---------------------------------------------------------

               You might want to compile your CoffeeScript files
               automatically when building the bundles. In this case,
               you can use Transform modules. This example uses
               Substack's `coffeeify` to compile CoffeeScript.

                   // with `npm install coffeeify`

                   module.exports = function(whisper) {
                     whisper.configure({
                       browserify: {
                         output: 'browser/all.js',
                         entry: ['lib/index.coffee'],
                         transform: ['coffeeify']
                       }
                     })
                   }

               ---------------------------------------------------------

               You likely want a saner way of debugging in development,
               you can use Whisper's environments to define
               debugging-ready bundles for development and
               optimised-bundles for production:

                   module.exports = function(whisper) {
                     whisper.configure({
                       browserify: {
                         output: 'browser/all.js',
                         entry: ['./']
                       }
                     })

                     whisper.configure('dev', {
                       browserify: {
                         debug: true,
                         globals: 'insert-globals'
                       }
                     })
                   }
               """
             , (env) -> do
                        (merge ...(env.browserify.map build-bundle))
                          .ok     -> whisper.log.info 'All bundles generated successfuly.'
                          .failed -> whisper.log.fatal 'Failed at generating some bundles.'
