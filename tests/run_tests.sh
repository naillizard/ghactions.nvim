#!/usr/bin/env lua

-- Add lua to Lua path
package.path = package.path .. ';../lua/?.lua;../lua/?/init.lua'

-- Run tests
local test_runner = require('minimal_test')
local success = test_runner.run_all()

-- Exit with appropriate code
os.exit(success and 0 or 1)