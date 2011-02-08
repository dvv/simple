## Aim

To provide simple means to write thin JSON REST/RPC server with _built-in_ security based on Object Capabilities. Most of existing similar projects
are about providing sugar to do routing and/or template rendering, paying no or little attention to security.

**Simple** is written in pure (CoffeeScript)[https://github.com/jashkenas/coffee-script] and uses:

- creationix's [Stack](https://github.com/creationix/stack) to form middleware

- jed's Secure [cookies](https://github.com/jed/cookie-node) to persist authenticated user id

- cloudhead's [node-static](https://github.com/cloudhead/node-static) to serve static content

- christkv's [node-mongodb-native](https://github.com/christkv/node-mongodb-native) as persistence layer

**Simple** can be run as single process, or as robust multi-node farm.

**Simple** talks _just_ JSON REST/RPC. All rendering is drawn as client-side task. I strongly suggest to look at (Backbone)[https://github.com/documentcloud/backbone] as client-side MVC.

**Simple** uses (Resource Query Language)[https://githib.com/kriszyp/rql] and provides very flexible and powerful way to semantically map URLs to DB queries.

**Simple** uses JSON-Schema to describe entities and validation rules. Changes are made to vanilla JSON-Schema so that it could express per-property access rules.

**Simple** uses facets to expose entity accessor methods to both web and internal business logic.

...More info to come...

## Install

Run:

    ./install

## Example

See [here](https://github.com/dvv/simple-example)

## License

Copyright 2011 Vladimir Dronnikov.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

