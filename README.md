LaunchBarActions
================

## Search through Evernote's notes

**Evernote Export** - an action to export all your notes from Evernote in folder /Users/userName/Library/Group Containers/Number.com.evernote.Evernote/Evernote/evernoteExport

**Evernote Index** - an action to manually run indexing to all your exported notes

**Evernote Search** - an action to search through exported Evernote notes. To use this action you should call **Evernote Export** before.

### How To
I've decided to found an easy way to search Evernote's notes by LaunchBar. Sadly my solution has 2 steps. In the first you should run **Evernote Export** to export all Evernote's notes to /Users/<userName>/Library/Group Containers/<Number>.com.evernote.Evernote/Evernote/evernoteExport

To search through the exported notes you should run **Evernote Search**.

### Indexing
**Evernote Export** and **Evernote Index** commands create an index file from all your notes. **Evernote Search** command uses it to search faster. The index file is stored in the storedindex file in the evernoteExport folder.

LaunchBar runs search script every time when you type. To not to load the index file every time all above commands create the ruby daemon which works like a small server. It listens druby://localhost:8787. Whole index file is kept in memory. If the daemon is already launched then a command will skip this step. Also the daemon stops old requests if you type new one. 

### Dependencies
To launch the daemon I use daemons library. It means that you should install it for the system ruby version. If you use rvm  you should remember which ruby you use now with ```rvm list``` and then type in a console:

```
rvm system
sudo gem install daemons
```

then rollback to the previous ruby version. If you don't use rvm you sholdn't do anything. 

Also **Evernote Export** and **Evernote Index** use unicode_utils but it seems that system ruby already has it.

For interprocess communications I use DRb.


![alt tag](https://raw.githubusercontent.com/soniccat/LaunchBarActions/master/img/EvernoteExport.png)

### To Do
1. Run exporting and indexing automatically every week

## Looking for English Irregular Verbs

**Irregular Verbs** - an action to show irregular verbs after you type
