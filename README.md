LaunchBarActions
================

## Search through Evernote's notes

**Evernote Search With Apple Script** - it looks through your notes using launched Evernote.app. Results are showed below the LaunchBar input as expected. The LaunchBar input works a little laggy because I decided it's better than listening how my computer uses its hardrive very actively. Every searching process happens on the main thread. The script works independently with scripts below, it's just an alternative solution.

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
The script uses a few libraries you have to install. Just type in a console:

```
sudo gem install nokogiri && gem install daemons && gem install unicode_utils && gem install ruby-stemmer
```

For interprocess communications I use DRb.


![alt tag](https://raw.githubusercontent.com/soniccat/LaunchBarActions/master/img/EvernoteExport.png)

### To Do
1. Run exporting and indexing automatically every week
2. Unload index from memory after a hour
3. Fix mistakes in search result
4. Fix a "can't connect to process" mistake

## Looking for English Irregular Verbs

**Irregular Verbs** - an action to show irregular verbs after you type
