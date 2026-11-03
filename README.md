# Mattermost plugin for Redmine

Posts Redmine issue and wiki notifications to [Mattermost](https://mattermost.com/) through a bot account and the Mattermost REST API.

This plugin is a fork of [redmine_messenger_so](https://github.com/smartorigin/redmine_messenger_so) (Smart/Origin), itself a fork of [redmine_messenger](https://github.com/alphanodes/redmine_messenger) (AlphaNodes). Support for Slack, Discord and Rocket.Chat has been removed.

## Features

* Issue notifications: creation, updates, private issues and private notes (optional), reopened issues only (optional)
* Changes, comments, attachments and the commit revision (when an issue is updated by a commit keyword) as message attachment fields
* Wiki notifications: page creation and page updates
* Mattermost mentions: default people to notify, and Redmine mentions (`@login`) converted to Mattermost mentions
* Direct messages to the users notified by Redmine
* Settings at system level, overridable per project, with inheritance from parent projects
* Several channels per project, and direct messages to fixed users (`@username`)
* Optional Mattermost server plugin to post as the user who acted in Redmine

## Requirements

* Redmine 6.0 or higher
* Ruby 3.1 or higher (as required by your Redmine version)
* Mattermost 12.0 or higher, with bot accounts enabled

## Mattermost setup

1. In the System Console, enable bot account creation (*Integrations > Bot Accounts*).
2. Create a bot account (*Integrations > Bot Accounts > Add Bot Account*). The image `assets/images/icon.png` can be used as its profile picture.
3. Create an access token for the bot and copy it: Mattermost shows it only once.
4. Add the bot to the teams and channels it posts to, or allow it to post to all public channels when creating it.
5. For direct messages, the bot must be able to open a direct message channel with the users (it shares a team with them).

Channels and teams are referenced by the name shown in their URL (`https://chat.example.com/<team>/channels/<channel>`), and users by their username. Redmine logins must match Mattermost usernames for mentions and direct messages.

## Installation

    cd $REDMINE_ROOT
    git clone https://github.com/EnhydraV/redmine_mattermost.git plugins/redmine_mattermost
    bundle config set --local without 'development test'
    bundle install
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production

The directory must be named `redmine_mattermost`. Restart Redmine, then configure the plugin in *Administration > Plugins > Mattermost*:

* **Mattermost server URL**: base URL of the server, e.g. `https://chat.example.com`
* **Bot access token**: the token created above. The `REDMINE_MATTERMOST_BOT_TOKEN` environment variable takes precedence over this field, which keeps the token out of the database.
* **Team** and **Channels**: default destination for all projects. `@username` in the channel list sends a direct message, `-` disables posting.

Each project can override these settings in *Settings > Mattermost* (permission *Manage Mattermost notifications*). Empty values are inherited from the parent project, then from the global settings.

## Posting as the acting user (optional)

With the server plugin in `mattermost-plugin/`, messages are published as the Mattermost user who acted in Redmine. Mattermost never notifies people of their own posts, so nobody is notified of what they just did in Redmine.

1. Build the plugin bundle (Go is required; the Makefile selects the Go 1.26 toolchain used by Mattermost):

       cd mattermost-plugin
       make bundle

   The bundle is written to `mattermost-plugin/dist/com.github.enhydrav.redmine-mattermost-<version>.tar.gz`.
2. In the System Console, *Plugins > Plugin Management*, upload the bundle (plugin uploads must be enabled) and enable the *Redmine relay* plugin.
3. In the plugin settings, set **Redmine bot account** to the username of the bot used by Redmine. Requests authenticated with any other account are refused.
4. In Redmine, check **Post as the acting user** in the plugin settings.

The Mattermost user is the one whose username is the Redmine login, or, failing that, the one with the same email address (this lookup can be disabled in the plugin settings). A message is posted by that user when they are allowed to post in the channel, and direct messages are sent from that user to the recipient. Otherwise the bot posts, as it does when the server plugin does not answer.

The server plugin lets the Redmine bot token publish as any user allowed to post in the target channel: keep the token out of the database with the `REDMINE_MATTERMOST_BOT_TOKEN` environment variable. A channel can still appear as unread to the user who acted, since posts created by a plugin do not mark the channel as viewed for their author.

Messages are sent by a background job (ActiveJob). Network errors and server errors (HTTP 429 and 5xx) are retried twice, 30 seconds apart; other errors are logged with the `[redmine_mattermost]` prefix.

## Migrating from redmine_messenger or redmine_messenger_so

The migrations of this plugin import the settings of the previous plugin (system settings and the `messenger_settings` table): channels, default mentions, notification options and direct messages. Webhook URLs, icons and usernames are not imported.

1. Remove the previous plugin directory from `plugins/` **without** running its uninstall migration, so that its table stays in the database.
2. Install this plugin and run the migrations as described above.
3. Set the server URL, the bot token and the team in the plugin settings.
4. Once everything works, remove the leftovers of the previous plugin:

       DELETE FROM settings WHERE name IN ('plugin_redmine_messenger', 'plugin_redmine_messenger_so');
       DELETE FROM schema_migrations WHERE version LIKE '%-redmine_messenger' OR version LIKE '%-redmine_messenger_so';
       DROP TABLE messenger_settings;

## Uninstall

    cd $REDMINE_ROOT
    bundle exec rake redmine:plugins:migrate NAME=redmine_mattermost VERSION=0 RAILS_ENV=production
    rm -rf plugins/redmine_mattermost

Restart Redmine.

## Development

Tests run inside a Redmine checkout:

    bundle exec rake redmine:plugins:test NAME=redmine_mattermost RAILS_ENV=test

Linting requires a `.enable_dev` file in the plugin directory (see `Gemfile`):

    bundle exec rubocop -S
    bundle exec slim-lint app/views

The Mattermost server plugin has its own tests:

    cd mattermost-plugin
    make test

## License

*redmine_mattermost* is released under the [MIT License](LICENSE).

## Credits

The source code is forked from:

* [redmine_messenger_so by Smart/Origin](https://github.com/smartorigin/redmine_messenger_so)
* [redmine_messenger by AlphaNodes](https://github.com/alphanodes/redmine_messenger)
* [redmine_rocketchat](https://github.com/phlegx/redmine_rocketchat)
* [redmine_mattermost](https://github.com/altsol/redmine_mattermost)
* [redmine-slack](https://github.com/sciyoshi/redmine-slack)

## Redmine Copyright

The redmine_mattermost is a plugin extension for Redmine Project Management Software, whose Copyright follows.
Copyright (C) 2006-  Jean-Philippe Lang

Redmine is a flexible project management web application written using Ruby on Rails framework.
More details can be found in the doc directory or on the official website <http://www.redmine.org>

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
