import { Meteor } from 'meteor/meteor';
import Winston from 'winston';

let Logger = new (Winston.Logger)({
    transports: [

      // Write logs to console
      new Winston.transports.Console({
            prettyPrint: false,
            humanReadableUnhandledException: true,
            colorize: true,
            handleExceptions: true,
          }),
      ],
    levels: { error: 0, warn: 1, info: 2, verbose: 3, debug: 4, silly: 5, },
    colors: {
      error: 'red',
      warn: 'yellow',
      info: 'green',
      verbose: 'cyan',
      debug: 'magenta',
      silly: 'gray',
    },
  });

// Set Logger message level priority for the console
Logger.transports.console.level = 'silly';

Meteor.startup(() => {
  const LOG_CONFIG = Meteor.settings.log || {};
  let filename = LOG_CONFIG.filename;

  // Determine file to write logs to
  if (filename) {
    if (Meteor.settings.runtime.env === 'development') {
      const path = Npm.require('path');
      filename = path.join(process.env.PWD, filename);
    }

    Logger.add(Winston.transports.File, {
      filename: filename,
      prettyPrint: true,
    });
  }
});

export default Logger;

export let logger = Logger;
