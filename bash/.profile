export TERM=xterm-color
export CLICOLOR=1
export LSCOLORS=GxGxCxdxcxegedabagAcAd

export PATH=~/bin:/usr/local/bin/:$PATH

# MacPorts Installer addition on 2010-11-21_at_05:11:36: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:/Users/semyonsemakov/.scripts:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.


# Setting PATH for MacPython 2.5
# The orginal version is saved in .profile.pysave
PATH="/System/Library/Frameworks/Python.framework/Versions/Current/bin:${PATH}"
export PATH

# Add android tools to path
export ANDROID_HOME=~/workspace/adt-bundle-mac-x86_64-20140702/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools:$HOME/.rvm/rubies/ruby-2.2.4/bin

export RAILS_ENV=development
# Enable programmable sdb completion features.
if [ -f ~/.sdb/.sdb-completion.bash ]; then
 source ~/.sdb/.sdb-completion.bash
fi

eval `boot2docker shellinit 2>/dev/null`
