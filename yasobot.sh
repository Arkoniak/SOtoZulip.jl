#!/bin/bash

cd $HOME/ZulipBots/SOtoZulip/
$HOME/.local/bin/julia --project=. yasobot.jl >> $HOME/logs/yasobot.log 2>&1
