

exec = require('child_process').exec

task 'compile', 'compile the project to javascript', (options) ->
    exec 'rm -r lib', (err) ->

        exec 'coffee -cbo lib src', (err, stdout, stderr) ->
            if err
                throw err

            exec 'find lib -name *.js -exec sed "1d" {} -i \\;', (err, stdout, stderr) ->
                if err
                    throw err

    exec 'coffee -cbo public/js/lib public/js/src', (err, stdout, stderr) ->
        if err
            throw err
        exec 'find public/js/lib -name *.js -exec sed "1d" {} -i \\;', (err, stdout, stderr) ->
            if err
                throw err
