# WPcap

WPcap is a set of capistrano reciepes designed to deploy wordpress instaliations to ubuntu 12.04 and up servers. It provides database and asset sync tasks, a helper appication to setup a brand new wordpress install ready to be deployed by wpcap.  

WPcap is opinionated, and currently reasonably narrow minded.  

WPcap assumptions

  * Local Macine is a Mac running MAMP
  * Remote Server is a brand new Ubuntu Server 
  * Passwordless access to remote server has be established (ssh keys) 
  * Wordpress is using mysql

WPcap server configuration

  * nginx stable
  * php5-fpm stable
  * mysql > 5.5
  * varnish (Optional)

## Installation

Add this line to your application's Gemfile:

    gem 'wpcap'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wpcap

## Usage

Create a new projet
  
    wpcap create mynewproject

Build a remote server
  
    cap deploy:install

Setup a remote server for this wordpress install

    cap deploy:setup

Deploy your latest code to the server

    cap deploy
    
Push Local Database and Assets to remote server

    cap db:push
    
Pull Remote Database and Assets to local enviroment

    cap db:pull
    
## Todo

  * Covert a predone wordpress install into a wpcap style directory
  * Do not require MAMP

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
