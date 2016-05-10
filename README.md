Tickwork - a scheduler library that requires an external call to tick to run scheduled events 
===========================================

[![Build Status](https://secure.travis-ci.org/softwaregravy/tickwork.png?branch=master)](http://travis-ci.org/softwaregravy/tickwork) [![Dependency Status](https://gemnasium.com/softwaregravy/tickwork.png)](https://gemnasium.com/softwaregravy/tickwork)

This started as a stripped down version of [clockwork](https://github.com/tomykaira/clockwork). 

Tickwork provides a familiar and compatible config file for scheduled jobs, but instead of it being driven by a background process, it relies on regular calls to `Tickwork.run`. `Tickwork.run` efectively ticks the clock forward from the last time it was called scheduling jobs as it goes. By tuning the paramters below, you can call `Tickwork.run` as little or as often as you like. 

Tickwork keeps track of time using a datastore. Right now, nothing is supported. 

Note that clockwork allowed schedules to be dynamically set via the database. This functionality does not exist in Tickwork.

Quickstart
----------

Create tick.rb:

```ruby
require 'tickwork'
module Tickwork
  configure do |config|
    # See DataStore below
    config[:data_store] = MyDataStore
  end
  handler do |job|
    puts "Running #{job}"
  end

  # handler receives the time when job is prepared to run in the 2nd argument
  # handler do |job, time|
  #   puts "Running #{job}, at #{time}"
  # end

  every(10.seconds, 'frequent.job')
  every(3.minutes, 'less.frequent.job')
  every(1.hour, 'hourly.job')

  every(1.day, 'midnight.job', :at => '00:00')
end
```

Note, this needs to be global to access the config whenever you run Tickwork. If you're on rails, this should be an initializer. 

If you need to load your entire environment for your jobs, simply add:

```ruby
require './config/boot'
require './config/environment'
```

under the `require 'tickwork'` declaration.

Then, somewhere else in your app, you need to regularly call `Tickwork.run`. 

Use with queueing
-----------------

The clock process only makes sense as a place to schedule work to be done, not
to do the work.  It avoids locking by running as a single process, but this
makes it impossible to parallelize.  For doing the work, you should be using a
job queueing system, such as
[Delayed Job](http://www.therailsway.com/2009/7/22/do-it-later-with-delayed-job),
[Beanstalk/Stalker](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend/),
[RabbitMQ/Minion](http://adam.heroku.com/past/2009/9/28/background_jobs_with_rabbitmq_and_minion/),
[Resque](http://github.com/blog/542-introducing-resque), or
[Sidekiq](https://github.com/mperham/sidekiq).  This design allows a
simple clock process with no locks, but also offers near infinite horizontal
scalability.

For example, if you're using Beanstalk/Stalker:

```ruby
require 'stalker'

module Tickwork
  handler { |job| Stalker.enqueue(job) }

  every(1.hour, 'feeds.refresh')
  every(1.day, 'reminders.send', :at => '01:30')
end
```

Using a queueing system which doesn't require that your full application be
loaded is preferable, because the clock process can keep a tiny memory
footprint.  If you're using DJ or Resque, however, you can go ahead and load
your full application enviroment, and use per-event blocks to call DJ or Resque
enqueue methods.  For example, with DJ/Rails:

```ruby
require 'config/boot'
require 'config/environment'

every(1.hour, 'feeds.refresh') { Feed.send_later(:refresh) }
every(1.day, 'reminders.send', :at => '01:30') { Reminder.send_later(:send_reminders) }
```



Event Parameters
----------

### :at

`:at` parameter specifies when to trigger the event:

#### Valid formats:

    HH:MM
     H:MM
    **:MM
    HH:**
    (Mon|mon|Monday|monday) HH:MM

#### Examples

The simplest example:

```ruby
every(1.day, 'reminders.send', :at => '01:30')
```

You can omit the leading 0 of the hour:

```ruby
every(1.day, 'reminders.send', :at => '1:30')
```

Wildcards for hour and minute are supported:

```ruby
every(1.hour, 'reminders.send', :at => '**:30')
every(10.seconds, 'frequent.job', :at => '9:**')
```

You can set more than one timing:

```ruby
every(1.day, 'reminders.send', :at => ['12:00', '18:00'])
# send reminders at noon and evening
```

You can specify the day of week to run:

```ruby
every(1.week, 'myjob', :at => 'Monday 16:20')
```

If another task is already running at the specified time, clockwork will skip execution of the task with the `:at` option.
If this is a problem, please use the `:thread` option to prevent the long running task from blocking clockwork's scheduler.

### :tz

`:tz` parameter lets you specify a timezone (default is the local timezone):

```ruby
every(1.day, 'reminders.send', :at => '00:00', :tz => 'UTC')
# Runs the job each day at midnight, UTC.
# The value for :tz can be anything supported by [TZInfo](http://tzinfo.rubyforge.org/)
```

### :if

`:if` parameter is invoked every time the task is ready to run, and run if the
return value is true.

Run on every first day of month.

```ruby
Tickwork.every(1.day, 'myjob', :if => lambda { |t| t.day == 1 })
```

The argument is an instance of `ActiveSupport::TimeWithZone` if the `:tz` option is set. Otherwise, it's an instance of `Time`.

This argument cannot be omitted.  Please use _ as placeholder if not needed.

```ruby
Tickwork.every(1.second, 'myjob', :if => lambda { |_| true })
```

### :thread

By default, clockwork runs in a single-process and single-thread.
If an event handler takes a long time, the main routine of clockwork is blocked until it ends.
Tickwork does not misbehave, but the next event is blocked, and runs when the process is returned to the clockwork routine.

The `:thread` option is to avoid blocking. An event with `thread: true` runs in a different thread.

```ruby
Tickwork.every(1.day, 'run.me.in.new.thread', :thread => true)
```

If a job is long-running or IO-intensive, this option helps keep the clock precise.

Configuration
-----------------------

Tickwork exposes a couple of configuration options:

### :logger

By default Tickwork logs to `STDOUT`. In case you prefer your
own logger implementation you have to specify the `logger` configuration option. See example below.

### :tz

This is the default timezone to use for all events.  When not specified this defaults to the local
timezone.  Specifying :tz in the parameters for an event overrides anything set here.

### :max_threads

Tickwork runs handlers in threads. If it exceeds `max_threads`, it will warn you (log an error) about missing
jobs.


### :thread

Boolean true or false. Default is false. If set to true, every event will be run in its own thread. Can be overridden on a per event basis (see the ```:thread``` option in the Event Parameters section above)

### :namespace

This prefixes keys with a namespace which is useful to prevent colisions if you are using redis or memcache as the datastore. Defautls to `_tickwork_`.

### Stepping forward in time from the past

Think about Tickwork as having a concept of now built into it, but rather than now moving with the clock, it only moves forward (ticks forward) when you tell it to. You tell it to tick forward through time by calling `Tickwork.run`. How much it ticks forward is controlled by the following variables. 

If you think of a clock, each tick is 1 second, and you take 1 tick each second. With tickwork, you control the size of the ticks, how many you take, and how often you take them.

Tickwork will never tick into the future.

### :tick_size

This is the interval in seconds that each tick will step forward. The original clockwork implementation would (by default) wake up every second to check for work. Tickwork defaults to 60 seconds. This effectively puts a floor on your frequency of events you can schedule. So if you scheduled something to run every 30 seconds, it would only be run every other time -- so don't do that. 

In general, set this to at least as small as your most frequently run job. If you set this to a value larger than 60, then events schedule to run at a particular time may be missed. 

### :max_ticks

This is the most number of ticks executed per run. If you have `tick_size` set to 60, then each tick will be 1 minute. If `max_ticks` is set to 10, then a call to `Tickwork.run` could result in as many as 10 minutes worth of jobs being scheduled. If you had 1 job that ran every minute, up to 10 jobs would be run. Tickwork will not tick into the future, so you may run fewer than this number of jobs. 

In any given call to `Tickwork.run`, you can move foward through time at most tick_size * max_ticks

### :max_catchup

When running tickwork, the last time you run it is important since that is what now. But what if your system goes down? `max_catchup` sets a floor on how far back Tickwork look back for jobs. This defaults to 3600 which is 1 hour. This means that if you run Tickwork for a day, then turn your system off for a day, then start running Tickwork again, it will start scheduling jobs from 1 hour ago.

Setting to 0 or nil disables the feature, and Tickwork will start from where it left off.

If there is no last timestamp, Tickwork starts from now. 

This must be larger than your `tick_size`, and probably significantly larger to avoid missing any jobs.

### :data_store

A datastore is required to save the times that jobs last run. This is how Tickwork keeps track of time. This can be anything that implements the following methods:

```ruby
def read(key)
end
def write(key, value)
end
```

ActiveSupport::Cache::Store satisfies this, so Rails users can use that. This must be a shared cache to work properly in an environment with multiple servers.



### Configuration example

```ruby
module Tickwork
  configure do |config|
    config[:logger] = Logger.new(log_file_path)
    config[:tz] = 'EST'
    config[:max_threads] = 15
    config[:thread] = true
    config[:tick_size] = 60
    config[:max_ticks] = 10
    config[:max_catchup] = 3600
  end
end
```

### External call frequency & configs

Since tickwork requires on some external system to make calls into `Tickwork.run`, you must balance whatever that system is against the config settings.

Lets say you call `Tickwork.run` every 5 minutes and you have no jobs trying to run faster than 1x/min. The default values will work well (`tick_size: 60, max_ticks: 10`). Every 5 minutes, you would expect to run 5 minutes worth of jobs. If you miss 1 period, you will catch up and run 10 minutes worth of jobs. However, if you miss 2 periods, then call back (after 15 min), it will take 2 calls to catch up since there are 15 minutes waiting to run, but `max_ticks` limits this to just 10 per call.


### error_handler

You can add error_handler to define your own logging or error rescue.

```ruby
module Tickwork
  error_handler do |error|
    Airbrake.notify_or_ignore(error)
  end
end
```

Current specifications are as follows.

- defining error_handler does not disable original logging
- errors from error_handler itself are not rescued, and stop clockwork

Any suggestion about these specifications is welcome.


Anatomy of a tick file
-----------------------

tick.rb is standard Ruby.  Since we include the Tickwork module, this
exposes a small DSL to define the handler for events, and then the events themselves.

The handler typically looks like this:

```ruby
handler { |job| enqueue_your_job(job) }
```

This block will be invoked every time an event is triggered, with the job name
passed in.  In most cases, you should be able to pass the job name directly
through to your queueing system.

The second part of the file, which lists the events, roughly resembles a crontab:

```ruby
every(5.minutes, 'thing.do')
every(1.hour, 'otherthing.do')
```

In the first line of this example, an event will be triggered once every five
minutes, passing the job name 'thing.do' into the handler.  The handler shown
above would thus call enqueue_your_job('thing.do').

You can also pass a custom block to the handler, for job queueing systems that
rely on classes rather than job names (i.e. DJ and Resque).  In this case, you
need not define a general event handler, and instead provide one with each
event:

```ruby
every(5.minutes, 'thing.do') { Thing.send_later(:do) }
```

If you provide a custom handler for the block, the job name is used only for
logging.

You can also use blocks to do more complex checks:

```ruby
every(1.day, 'check.leap.year') do
  Stalker.enqueue('leap.year.party') if Date.leap?(Time.now.year)
end
```

In addition, Tickwork also supports `:before_tick` and `after_tick` callbacks.
They are optional, and run every tick (a tick being whatever your `:sleep_timeout`
is set to, default is 1 second):

```ruby
on(:before_tick) do
  puts "tick"
end

on(:after_tick) do
  puts "tock"
end
```

Use cases
---------

Feel free to add your idea or experience and send a pull-request.

- [Sending errors to Airbrake](https://github.com/tomykaira/clockwork/issues/58)

Meta
----

Created by Adam Wiggins

Inspired by [rufus-scheduler](https://github.com/jmettraux/rufus-scheduler) and [resque-scheduler](https://github.com/bvandenbos/resque-scheduler)

Design assistance from Peter van Hardenberg and Matthew Soldo

Patches contributed by Mark McGranaghan and Lukáš Konarovský

Released under the MIT License: http://www.opensource.org/licenses/mit-license.php

http://github.com/tomykaira/clockwork
http://github.com/softwaregravy/tickwork
