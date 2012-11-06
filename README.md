# WPcap

WPcap is a set of capistrano recipes designed to deploy wordpress instaliations to ubuntu 12.04 and up. It provides database and asset sync tasks, per deploy mysql backups, a helper appication to setup a brand new wordpress install ready to be deployed.  

WPcap is opinionated, and currently reasonably narrow minded.  

WPcap expectations

  * Local Macine is a Mac running MAMP (for now)
  * Remote Server is a brand new Ubuntu Server 
  * Passwordless access to remote server has be established (ssh keys) **Capistrano Requirment**
  * Using a SMTP Mailer Plugin for E-Mail delivery ie. wp-mail-smtp

WPcap server configuration

  * nginx stable
  * php5-fpm stable
  * mysql > 5.5
  * memcached
  * varnish (Optional)
  
  Base
  * git
  * debconf-utils
  * python-software-properties

## Installation

Install it:

    gem install wpcap

## Usage

Create a new projet
  
    wpcap create mynewproject

Convert an existing project to WPcap (Incomplete)

    wpcap build PATH-TO-WORDPRESS-FOLDER

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
    
List Backups and Resotre

    cap backups
    
## Todo

  * Covert a predone wordpress install into a wpcap style directory
  * Do not require MAMP
  * Allow users to customize templates by placing them in their config directory (think devise generators for views)
  * Automate mysql_secure_installation
  * Offsite (s3) Backups 
  * Backup Asset Directory
  * Add Sendmail Receipe and Config (Maybe?)
  
  

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
