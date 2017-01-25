var express = require('express');
var request = require('request');
var async = require('async');
var exec = require('child_process').exec;
var fs = require('fs');
var sources = require('./sources.json');
var MongoClient = require('mongodb').MongoClient;
var url = 'mongodb://webcmd:9whirls@ds135797.mlab.com:35797/9whirls';
var errList = require('./error_codes.json');

function load_cmd(repo,cb) {
  var addr = sources[repo];
  request({
    url: addr,
    json: true
  }, function (error, response, body) {
    if (!error && response.statusCode === 200) {
      for (var j=0; j<body.length; j++) {
        body[j].repository = repo;
      }
      cb(null, body);
    }
  });
}

var cmdList = [];
async.concat(Object.keys(sources), load_cmd, function(err, results) {
  cmdlist = results;
});

function find_doc(db, cb) {
  var collection = db.collection('history');
  collection.find({}).toArray(function(err, docs) {
    cb(docs);
  });
}

function find_err_code(content) {
  for (var i in Object.keys(errList)) {
    var code = Object.keys(errList)[i];
    var err = errList[code];
    if (content.indexOf(err) != -1) { return code; }
  }
  if (content.indexOf("Fail -") != -1) { return "4444"; }
  return "4488";
}

var app = express();
app.use(express.static(__dirname + '/www/'));
var bodyParser = require('body-parser');
var jsonParser = bodyParser.json();

app.get('/list-cmd', function (req, res) {
  res.end(JSON.stringify(cmdlist));
});
app.get('/list-err', function (req, res) {
  res.end(JSON.stringify(errlist));
});
app.get('/script/:path(*)', function (req, res) {
  var cmdFound = cmdlist.filter(function(item) {
    return item.script.replace(/\\/g, '\/') == req.params.path;
  });
  res.end(JSON.stringify(cmdFound));
});
app.get('/list-history', function (req, res) {
  MongoClient.connect(url, function(err, db) {
    find_doc(db, function(docs) {
      res.end(JSON.stringify(docs));
      db.close();
    });
  });
});
app.post('/run-cmd', jsonParser, function(req, res) {
  res.setHeader("Content-Type", "application/json");
  var t1 = (new Date).getTime();
  var cmd = "set runFromWeb=true & powershell -noninteractive ./exec.ps1 ";
  var json = req.body;
  var script = json.script;
  cmd += script;
  var params = json.parameters;
  for (var name in params){
    cmd += " -" + name + " " + encodeURIComponent(params[name]);
  }
  var method = json.method;
  if (method) {cmd += " -" + method;}
  
  exec(cmd, {cwd: "./powershell"}, function (err, stdout, stderr) {
    if (err) {
      console.error(err);
      return;
    }
    var border = stdout.indexOf("VERBOSE");
    if (border != 0) {
      var rawoutput = stdout.slice(0, border);
      json.rawoutput = rawoutput;
      stdout = stdout.slice(border);
    }  
    var result = stdout.replace(/VERBOSE: /g, '').replace(/[\u0000-\u0019]+/g,"");
    json.output = JSON.parse(result);
    var d = new Date();
    json.time = d.toLocaleString(); 
    var t2 = d.getTime();
    json.executiontime = (t2 - t1) / 1000 + " seconds";
    json.returncode = find_err_code(result);
    json.useraddr = req.headers['x-forwarded-for'] || 
      req.connection.remoteAddress || 
      req.socket.remoteAddress ||
      req.connection.socket.remoteAddress;
    json.useragent = req.headers['user-agent'];
    res.end(JSON.stringify(json));
    MongoClient.connect(url, function(err, db) {
      var collection = db.collection('history');
      collection.insert(json, function(){
        db.close();
      });
    });
  });
});
app.listen(8080);