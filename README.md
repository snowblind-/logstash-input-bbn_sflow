# logstash-input-bbn_sflow
This plugin is used to collect and process sFlow v5 data. Data is parsed and converted to json blobs and can be passed on to the elasticsearch output plugin or logstash-output-bbn_event.

## Installing a test system
Easist way to test the plugin would be to install a Ubuntu server.

## Installing dependencies
The following dependencies needs to be installed via apt-get

  sudo apr-get install git openjdk-7-jdk

## Install latest version of JRuby
All plugin development for logstash is done with JRuby. Install the latest version of JRuby (currently 1.7.19), can be found here: https://s3.amazonaws.com/jruby.org/downloads/1.7.19/jruby-bin-1.7.19.tar.gz 
  
Extract the file and put the entire directory in /usr/local/lib/.

<i>
  devops-github@devsrv10:~$ ls -la /usr/local/lib<br>
  total 20<br>
  drwxr-xr-x  5 root root  4096 Mar 22 05:56 .<br>
  drwxr-xr-x 10 root root  4096 Mar 22 05:43 ..<br>
  drwxr-xr-x  7 root root  4096 Jan 29 09:35 jruby-1.7.19<br>
</i>

Next step would be to add JRUBY_HOME and JRUBY_HOME/bin into your PATH environment variable.

Edit /etc/environment and add the following line to the top of the file <i>JRUBY_HOME="/usr/local/lib/jruby-1.7.19"</i>

Then create a file called jrubyenvvar.sh in <i>/etc/profile.d/</i> and add the follwoing line <i>export PATH=$PATH:$JRUBY_HOME/bin</i>

After that restart your server. Once server comes back up verify the <i>PATH</i> changes by typing <i>export</i>. You should see the output containg the foloowing:

<i>
  devops-github@devsrv10:~$ export<br>
  declare -x HOME="/home/devops-github"<br>
  declare -x JRUBY_HOME="/usr/local/lib/jruby-1.7.19"<br>
  ...<br>
  declare -x PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/lib/jruby-1.7.19/bin"<br>
  ...<br>
</i>

To be able to run the pre-compiled JRuby binaries in super-user mode you need to add them to the /usr/bin/ path manually (or any other secure_path on your system).

Simpliest way would be to create a sym link to the original file from /usr/bin/

<i>
  devops-github@devsrv10:~$ sudo ln -s /usr/local/lib/jruby-1.7.19/bin/jruby /usr/bin/  <br>
  devops-github@devsrv10:~$ sudo ln -s /usr/local/lib/jruby-1.7.19/bin/gem /usr/bin/    <br>
  devops-github@devsrv10:~$ sudo ln -s /usr/local/lib/jruby-1.7.19/bin/jgem /usr/bin/   <br>
</i>

At this point you should be able to execute the jruby binary directly from the commandline without using the full path.

<i>
  devops-github@devsrv10:~$ jruby -v  <br>
  jruby 1.7.19 (1.9.3p551) 2015-01-29 20786bd on OpenJDK 64-Bit Server VM 1.7.0_75-b13 +jit [linux-amd64] <br>
</i>

Once you verified that <i>jruby, gem and jgem</i> runs without any errors you need to <i>install bundler and rspec via gem</i>. Run the follwoing commands to install the two packets.

<i>
  devops-github@devsrv10:~$ sudo gem install bundler  <br>
  devops-github@devsrv10:~$ sudo gem install rspec    <br>
</i>

## Installing Logstash
Then install >= logstash-1.5.0rc2. The plugin has been developed with this specific release of logstash.

The above logstash release can be found at: http://download.elasticsearch.org/logstash/logstash/packages/debian/logstash_1.5.0.rc2-1_all.deb

<i>
  devops-github@devsrv10:~$ sudo dpkg -i <path to logstash_1.5.0.rc2-1_all.deb> <br>
</i>

Logstash installs itself in /opt/logstash.

## Clone the latest version of the plugin
The 
