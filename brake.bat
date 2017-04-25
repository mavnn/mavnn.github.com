echo on
REM activate py27
chcp 65001
echo %*
bundle exec rake %*
REM deactivate
