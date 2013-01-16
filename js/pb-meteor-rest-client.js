/////////////////////////////////////////////////////////////////////////////////
// External dependencies
// Note: Dojo library must already be loaded before this script is called.
/////////////////////////////////////////////////////////////////////////////////
define([
    "dojo/parser", 
    "dojo/_base/connect",
    "dojo/_base/array",
    "dojo/request/xhr",
    "dojo/_base/json",
    "dojo/data/ItemFileWriteStore",
       ], 
    function(parser, connect, array, xhr, dojo, ItemFileWriteStore) {
	   
    /////////////////////////////////////////////////////////////////////////////////
    // Internal vars
    /////////////////////////////////////////////////////////////////////////////////
	var debug_lvl = 100;
	
	var _pb_puzzstore_structure = {identifier: 'name', label: 'name', items: []};
	var _pb_puzzstore = new ItemFileWriteStore({data: _pb_puzzstore_structure});
	var _pb_puzzstore_init_complete = 0;
	
	var _pb_solverstore_structure = {identifier: 'name', label: 'name', items: []};
	var _pb_solverstore = new ItemFileWriteStore({data: _pb_solverstore_structure});
	var _pb_solverstore_init_complete = 0;
	
	var _pb_dataversion = -1;

	var _pb_meteor_dataversion_enabled = true;
	var _pb_dataversion_queued = -1;

	var _pb_clientindex;
	var _pb_puzzArrivalCounter = 0;
	var _pb_solverArrivalCounter = 0;
	var _pb_totalPuzz = 0;
	var _pb_totalSolvers = 0;
	
	var _pb_roundlist = null;
	var _pb_config = new Object();
	var _pb_puzzstore_onset_handler_connection;
	var _pb_solverstore_onset_handler_connection;
	
	/////////////////////////////////////////////////////////////////////////////////
	// Callback registry (for those registered to hear from us)
	/////////////////////////////////////////////////////////////////////////////////
	var _pb_cb_init_complete;
	var _pb_cb_add_round;
	var _pb_cb_update_puzzle;
	var _pb_cb_received_updated_part;
	var _pb_cb_update_solver;
	var _pb_cb_error;
	var _pb_cb_warning;
	var _pb_cb_connection_status;
	var _pb_cb_connection_mode;
	var _pb_filter_version_diff;
    
    
	/////////////////////////////////////////////////////////////////////////////////
	// Internal utility functions
	/////////////////////////////////////////////////////////////////////////////////
    
	function _pb_comm_warn(msg) {
	    _pb_log("_pb_comm_warn()",2);
	    console.warn(msg);
	    _pb_cb_warning(msg);
	}
    
	function _pb_comm_fail(msg) {
	    _pb_log("_pb_comm_fail()",2);
	    console.warn(msg);
	    _pb_cb_warning(msg);
	}
    
	function _pbrest_post(path, data, loadcb, errcb) {
		xhr.post(_pb_config.pbrest_root+"/"+path, {
			sync: false, 
			handleAs: "text",
			preventCache: true,
			data: dojo.toJson(data),
			headers: {"Content-Type":"text/x-json"}
		}).then(function(jsondata) {
			_pb_log("_pbrest_post: jsondata:"+jsondata, 10);
			var data
			try {
				data = dojo.fromJson(jsondata);
			} catch (x) {
				_pb_log("_pbrest_post: caught exception converting response fromJson: "+x);
				// error converting to json - probably a login page or capture portal
				if(jsondata.match(/html/i) && jsondata.match(/login/i)) {
					_pb_comm_fail("Error retrieving "+path+". You may be logged out or behind a captive portal. The page should reload automatically in 5 seconds. If it does not, please reload it manually to continue.");
					setTimeout(function(){
						window.location.reload( true );
					}, 5000);
				} else {
					_pb_comm_warn("Error retrieving "+path);
				}
			}
			if (data.status == "error"){
			    errcb(data);
			}else{
			    loadcb(data);
			}
		}, function(err) {
			_pb_log("_pbrest_post: error:", 10);
			_pb_log(err, 10);
			errcb(err);
		}, function(evt) {
			_pb_log("_pbrest_post: event:", 10);
			_pb_log(evt, 10);
		});
	}
	
	function _pbrest_get(path, loadcb, errcb) {
	    xhr.get(_pb_config.pbrest_root+"/"+path, {
			sync: false,
			handleAs: "text",
			preventCache: true
		    }).then(function(jsondata) {
				 _pb_log("_pbrest_get: jsondata:"+jsondata, 10);
				var data
				try {
				     data = dojo.fromJson(jsondata);  
				 } catch (x) {
				     _pb_log("_pbrest_get: caught exception converting toJson: "+x);
				     // error converting to json - probably a login page or capture portal
		                     if(jsondata.match(/html/i) && jsondata.match(/login/i)) {
					 _pb_comm_fail("Error retrieving "+path+". You may be logged out or behind a captive portal. The page should reload automatically in 5 seconds. If it does not, please reload it manually to continue.");
					 setTimeout(function(){
							window.location.reload( true );
						    }, 5000);
				     } else {
					 _pb_comm_warn("Error retrieving "+path);
				     }
				 }
				_pb_log("_pbrest_get: data:", 10);
				_pb_log(data, 10);
				if (data.status == "error"){
				    errcb(data);
				}else{
				    loadcb(data);
				}
			    }, function(err) {
				_pb_log("_pbrest_get: error:"+err, 10);
				errcb(err);
			    }, function(evt) {
				_pb_log("_pbrest_get: event:"+evt, 10);
			    });
	}
       
	function _pb_puzzstore_data_set_handler(item, attribute, oldValue, newValue) {
		_pb_log("_pb_puzzstore_data_handler("+item.id+","+attribute+","+oldValue+","+newValue+")",2);
		// called when puzzle data store changes from our user
		if(!(oldValue==newValue)) {
			var wrapdata = new Object();
			wrapdata.data = newValue;
			_pb_log("_pb_puzzstore_data_handler: posting change for puzzle["+item.id+"]="+_pb_puzzstore.getLabel(item)+" for part "+attribute+" from ["+oldValue+"] to ["+newValue+"]",1);
			_pbrest_post("puzzles/"+_pb_puzzstore.getLabel(item)+"/"+attribute,
			wrapdata,_pb_post_puzzle_part_cb, function(err) {_pb_log("_pb_puzzstore_data_set_handler: error from _pbrest_post:"+err,1)});
		}
	}
	
	function _pb_solverstore_data_set_handler(item, attribute, oldValue, newValue) {
		_pb_log("_pb_solverstore_data_set_handler("+item.id+","+attribute+","+oldValue+","+newValue+")",2);
		// called when solver data store changes from our user
		if(!(oldValue==newValue)) {
			var wrapdata = new Object();
			wrapdata.data = newValue;
			_pb_log("_pb_solverstore_data_set_handler: posting change for solver["+item.id+"]="+_pb_solverstore.getLabel(item)+" for part "+attribute+" from ["+oldValue+"] to ["+newValue+"]",1);
			_pbrest_post("solvers/"+_pb_solverstore.getLabel(item)+"/"+attribute,
			wrapdata,_pb_post_solver_part_cb, function(err) {_pb_log("_pb_solverstore_data_set_handler: error from _pbrest_post:"+err,1)});
		}
	}
    
	function _pb_puzzstore_enable_handlers() {
		_pb_puzzstore_onset_handler_connection = connect.connect(_pb_puzzstore, "onSet", _pb_puzzstore_data_set_handler);
	}
    
	function _pb_puzzstore_disable_handlers() {
		connect.disconnect(_pb_puzzstore_onset_handler_connection);
	}
    
	function _pb_solverstore_enable_handlers() {
		_pb_solverstore_onset_handler_connection = connect.connect(_pb_solverstore, "onSet", _pb_solverstore_data_set_handler);
	}
    
	function _pb_solverstore_disable_handlers() {
		connect.disconnect(_pb_solverstore_onset_handler_connection);
	}
    
	/////////////////////////////////////////////////////////////////////////////////
	// Meteor functions
	/////////////////////////////////////////////////////////////////////////////////
    
	function _pb_meteor_init(hostid) {
		_pb_log("_pb_meteor_init()",2);
		// start listening to meteor
		Meteor.hostid = hostid;
		Meteor.host = _pb_config.meteor_http_host;
		Meteor.registerEventCallback("process", _pb_meteor_process_cb);
		Meteor.registerEventCallback("changemode", _pb_meteor_changemode_cb);
		Meteor.registerEventCallback("statuschanged", _pb_meteor_statuschanged_cb);
		Meteor.registerEventCallback("eof", _pb_meteor_eof_cb);
		Meteor.registerEventCallback("reset", _pb_meteor_reset_cb);
		Meteor.joinChannel(_pb_config.meteor_version_channel,1);
		Meteor.mode = 'stream';
		_pb_log("_pb_meteor_init: connecting meteor"+" (_pb_clientindex "+_pb_clientindex+")",1);
//	    Meteor.debugmode=true;
		Meteor.connect();
		_pb_cb_connection_mode(Meteor.mode);
	}
    
	function _pb_meteor_eof_cb() {
		_pb_log("_pb_meteor_eof_cb()",2);
		_pb_comm_warn("warning: asynchronous communications interrupted. "+" (_pb_clientindex "+_pb_clientindex+")");
		//_pb_cb_connection_mode(Meteor.mode);
	}
    
	function _pb_meteor_reset_cb() {
		_pb_log("_pb_meteor_reset_cb()",2);
		//This happens a fuck-ton, so probably shouldn't warn with popup?
		//_pb_comm_warn("warning: asynchronous communications reset. "+" (_pb_clientindex "+_pb_clientindex+")");
		_pb_cb_connection_mode(Meteor.mode);
	}
    
	function _pb_meteor_changemode_cb(newmode) {
		_pb_log("_pb_meteor_changemode_cb()",2);
		_pb_comm_warn("warning: asynchronous communications mode changed. falling back to "+newmode+" (_pb_clientindex "+_pb_clientindex+")");
		_pb_cb_connection_mode(newmode);
	}
    
	function _pb_meteor_statuschanged_cb(newstatus) {
		_pb_log("_pb_meteor_statuschanged_cb(),2");
		// Statuses
		//0 = Uninitialised,
		//1 = Loading stream,
		//2 = Loading controller frame,
		//3 = Controller frame timeout, retrying.
		//4 = Controller frame loaded and ready
		//5 = Receiving data
		//6 = End of stream, will not reconnect
		if(newstatus==5) {
			_pb_cb_connection_status("receiving", newstatus);
		} else if(newstatus==6) {
			_pb_cb_connection_status("eof", newstatus);
		} else if(newstatus==4) {
			_pb_cb_connection_status("ready", newstatus);
		} else if(newstatus==3) {
			_pb_cb_connection_status("timeout", newstatus);
		} else {
			_pb_cb_connection_status("loading", newstatus);
		}
	}
    
	function _pb_meteor_modechanged_cb(newmode) {
		_pb_log("_pb_meteor_modechanged_cb()",2);
		//stream, xhrinteractive, iframe, serversent
		//poll, smartpoll, longpoll
		_pb_cb_connection_mode(newmode);
	}
    
	function _pb_meteor_process_cb(version) {
	    _pb_log("_pb_meteor_process_cb("+version+")",2);
	    // disable receiving of meteor updates until we have finished processing this one! (i.e. in the callback from the pbrest)
	    //alert("meteor has:"+version);
	    //dojo.byId("debugme").innerHTML += " "+version;
	    if(_pb_meteor_dataversion_enabled && (version > _pb_dataversion)) {
		_pb_log("_pb_meteor_process_cb: new data exists! (we have version "+_pb_dataversion+", but "+version+" exists on server.)",1);
		_pb_meteor_dataversion_enabled = false;
		_pbrest_get("version/"+_pb_dataversion,_pb_get_version_diff_cb);
	    } else if(!_pb_meteor_dataversion_enabled) {
		_pb_log("_pb_meteor_process_cb: dataversion processing disabled",3);
		if(version > _pb_dataversion_queued) {
		    _pb_log("_pb_meteor_process_cb: updating queued version to "+version+" (for later processing)",3);
		    _pb_dataversion_queued = version;
		} else {
		    _pb_log("_pb_meteor_process_cb: received version not newer than existing queued data version",3);
		}
	    } else {
		_pb_log("_pb_meteor_process_cb: dataversion processing enabled, but version not newer than existing data version",3);
	    }
	}
    
    
    
    
	/////////////////////////////////////////////////////////////////////////////////
	// Callback functions (non-init)
	/////////////////////////////////////////////////////////////////////////////////
    
	function _pb_get_version_diff_cb(data, ioArgs) {
	    _pb_log("_pb_get_version_diff_cb()",2);
	    //console.dir(data);
	    _pb_dataversion = data.to;
	    
		if(!_pb_meteor_dataversion_enabled && (_pb_dataversion_queued > _pb_dataversion)) {
			_pb_meteor_dataversion_enabled = true;
			_pbrest_get("version/"+_pb_dataversion, _pb_get_version_diff_cb);
		}
		_pb_meteor_dataversion_enabled = true;
	    
	    _pb_log("_pb_get_version_diff_cb: before filtering, we have "+data.diff.length+" items in diff",1);
	    var diff = _pb_filter_version_diff(data.diff);
	    _pb_log("_pb_get_version_diff_cb: after filtering, we have "+diff.length+" items in diff",1);
	    for(i in diff) {
			var path = diff[i];
			var splitpath = path.split('/');
			if(splitpath[0]=="puzzles") {
				if(splitpath[1]) {
					if(splitpath[2]) {
						_pbrest_get(path, _pb_get_puzzle_part_cb);
					} else {
						_pbrest_get(path, _pb_get_puzzle_cb);
						//_pbrest_get("puzzles", _pb_get_puzzlelist_cb);
					}
				}else if (splitpath[2]) {
					//if the puzzle ID is null, but part is specified, do nothing.
					// i.e. this is an update to the solver pool (NOT IMPLEMENTED)
				}else{
					_pbrest_get(path, _pb_get_puzzlelist_cb);
				}
			} else if(splitpath[0]=="rounds") {
				if(splitpath[1]) {
					if(splitpath[2]) {
						//_pbrest_get(path, _pb_get_round_part_cb);
						_pb_cb_warning("_pb_get_version_diff_cb: no handler defined for path "+path+" starting with "+splitpath[0]);
					} else {
						//_pb_cb_warning("_pb_get_version_diff_cb: no handler defined for path "+path+" starting with "+splitpath[0]);
						//Should we be warning that we can't get an individual round?
						_pbrest_get("rounds", _pb_get_roundlist_cb);
					}
				} else {
					_pb_log("requesting _pb_roundlist",1);
					_pbrest_get(path, _pb_get_roundlist_cb);
				}
			} else if (splitpath[0]=="solvers") {
				if(splitpath[1]) {
					if(splitpath[2]) {
						if (splitpath[2]=="puzzles"){
							//this is a little hacky.
							path = "solvers/"+splitpath[1]+"/puzz";
						}
						_pbrest_get(path, _pb_get_solver_part_cb);
					} else {
						_pbrest_get(path, _pb_get_solver_cb);
						//_pbrest_get("solvers", _pb_get_solverlist_cb);
					}
				} else {
					_pbrest_get(path, _pb_get_solverlist_cb);
				}
			}else if (splitpath[0]=="locations"){
				//TODO: not implemented
			} else {
				_pb_cb_warning("_pb_get_version_diff_cb: no handler defined for path "+path+" starting with "+splitpath[0]);
			}
		}
	}
    
	function _pb_get_roundlist_cb(response, ioArgs) {
		// round updates
		_pb_log("_pb_get_roundlist_cb()",2);
		new_pb_roundlist = response;
		var haveround = Array();
		var _i;
		var _roundname;
		for(_i in _pb_roundlist) {
			_roundname = _pb_roundlist[_i];
			haveround[_roundname] = 1;
		}
		for(_i in new_pb_roundlist) {
			_roundname = new_pb_roundlist[_i];
			if(haveround[_roundname] !== 1) {
				_pb_log("_pb_get_roundlist_cb: firing off _pb_cb_add_round callback for "+_roundname,1);
				_pb_cb_add_round(_roundname);
			}
		}
		_pb_roundlist = new_pb_roundlist;
	}
    
	function _pb_get_puzzlelist_cb(puzzlelist, ioArgs) {
		_pb_log("_pb_get_puzzlelist_cb: puzzlelist: "+puzzlelist+" (UNIMPLEMENTED)",2);
		_pb_totalPuzz = puzzlelist.length;
		// diff and get new puzzles???
	}
    
	function _pb_get_puzzle_cb(puzzle, ioArgs) {
		_pb_log("_pb_get_puzzle_cb: puzzle: "+puzzle.name,1);
		_pb_puzzArrivalCounter++;
		// add to puzzstore
		_pb_puzzstore.newItem(puzzle);
		_pb_log("_pb_get_puzzle_cb: saving store",2);	
		_pb_puzzstore.save({onComplete: _pb_puzzle_save_complete_cb, onError: _pb_save_error_cb});
		// fire off callback
		//_pb_cb_update_puzzle(puzzle);
	}
    
	function _pb_get_puzzle_part_cb(response, ioArgs){
		_pb_log("_pb_get_puzzle_part_cb()",2);
		// update in store from server
		_pb_puzzstore.fetchItemByIdentity({
			identity: response.id,
			onItem: function(item) {
				_pb_puzzstore_disable_handlers();
				_pb_puzzstore.setValue(item,response.part,response.data);
				_pb_puzzstore.save({onComplete: _pb_puzzle_save_complete_cb, onError: _pb_save_error_cb});
				_pb_puzzstore_enable_handlers();
			}
		});
		// fire off callback
		_pb_cb_received_updated_part("puzzle", response.id, response.part, response.data);
	}
	
	function _pb_get_solverlist_cb(solverlist, ioArgs) {
		_pb_log("_pb_get_solverlist_cb: solverlist: "+solverlist+" (UNIMPLEMENTED)",2);
		_pb_totalSolvers = solverlist.length;
	}
    
	function _pb_get_solver_cb(solver, ioArgs) {
		_pb_log("_pb_get_solver_cb: solver: "+solver.name,1);
		_pb_solverArrivalCounter++;
		// add to solverstore
		_pb_solverstore.newItem(solver);
		_pb_log("_pb_get_solver_cb: saving store",2);	
		_pb_solverstore.save({onComplete: _pb_solver_save_complete_cb, onError: _pb_save_error_cb});
		// fire off callback
		//_pb_cb_update_puzzle(puzzle);
	}
	
	function _pb_get_solver_part_cb(response, ioArgs){
		_pb_log("_pb_get_solver_part_cb()",2);
		// update in store from server
		_pb_solverstore.fetchItemByIdentity({
			identity: response.id,
			onItem: function(item) {
				_pb_solverstore_disable_handlers();
				_pb_solverstore.setValue(item,response.part,response.data);
				_pb_solverstore.save({onComplete: _pb_solver_save_complete_cb, onError: _pb_save_error_cb});
				_pb_solverstore_enable_handlers();
			}
		});
		// fire off callback
		_pb_cb_received_updated_part("solver", response.id, response.part, response.data);
	}
	
	
	function _pb_puzzle_save_complete_cb() {
		_pb_log("puzzstore save successful",2);
		_pb_cb_update_puzzle();
	}
    
	function _pb_solver_save_complete_cb(){
		_pb_log("solverstore save successful",2);
		_pb_cb_update_solver();
	}
	
	function _pb_save_error_cb() {
		_pb_log("store save failed",2);
		alert("store save failed");
		_error_cb("store save failed");
	}
    
	function _pb_post_puzzle_part_cb(response, ioArgs){
		_pb_log("_pb_post_puzzle_part_cb()",2);
		if(response != null && "error" in response) {			
			var path = "puzzles/"+response.id+"/"+response.part;
			_pb_cb_warning("Error while attempting to update ["+path+"] to ["+response.data+"]: " + response.error);
			_pbrest_get(path, _pb_get_puzzle_part_cb);
		}
	}
	
	function _pb_post_solver_part_cb(response, ioArgs){
		_pb_log("_pb_post_solver_part_cb()",2);
		if(response != null &&"error" in response) {
			var path = "solvers/"+response.id+"/"+response.part;
			_pb_cb_warning("Error while attempting to update ["+path+"] to ["+response.data+"]: " + response.error);
			_pbrest_get(path, _pb_get_solver_part_cb);
		}
	}
    
	function _pb_create_round_cb(roundid, ioArgs) {
		//could alert user that round has been created, but dialog is too in-your-face
		//First time PB might be confused, but afterwards they'll just be annoyed by it.
		//maybe we should have a little log box somewhere?
		_pb_log("_pb_create_round_cb: UNIMPLEMENTED",3);
	}
   
    
    
    /////////////////////////////////////////////////////////////////////////////////
    // Internal Initialization Process (Functions and Callbacks)
    /////////////////////////////////////////////////////////////////////////////////
    
    // 1. Phase 1 init: called after setting internal callback handlers
    // requests version
	function _pb_init() {
		// get initial data version first
		_pbrest_get("version",_pb_get_version_cb_init);
		// get rounds here?
		_pbrest_get("rounds",_pb_get_roundlist_cb_init); //FIXME does this not work???
	}
    
	// 1a. have version, proceed to phase 2
	function _pb_get_version_cb_init(data, ioArgs) {
		_pb_dataversion = data.version;
		_pb_log("_pb_get_version_cb_init:"+_pb_dataversion,1);
		_pb_init_phase2();
	}
    
	// 1b. have roundlist, save for later
	function _pb_get_roundlist_cb_init(response, ioArgs) {
		// initial round list
		_pb_log("_pb_get_roundlist_cb_init(): have ["+response+"]",1);
		_pb_roundlist = response;
	}    
	
	// 2. Phase 2 init: request client UID (clientindex) and puzzlelist
	function _pb_init_phase2() {
		_pb_log("_pb_init_phase2()",1);
		// connect stores update to handlers
		_pb_puzzstore_enable_handlers(); 
		_pb_solverstore_enable_handlers();		
	
		// get client version (and start meteor in CB)
		_pbrest_get("client",_pb_get_client_index_cb_init);
	
		// get puzzle list
		_pbrest_get("puzzles",_pb_get_puzzlelist_cb_init);

	        // get solver list
		_pbrest_get("solvers",_pb_get_solverlist_cb_init);
	} // end of _pb_init_phase2     
    
	// 2.a.1 have clientindex, start meteor
	function _pb_get_client_index_cb_init(data, ioArgs) {
		_pb_clientindex = data.clientindex;
		_pb_log("received client index "+_pb_clientindex,1);
		_pb_meteor_init(_pb_clientindex);
	}
    
	// 2.b.1 have puzzles (puzzlelist), request each puzzle
	function _pb_get_puzzlelist_cb_init(puzzlelist, ioArgs) {
		_pb_log("_pb_get_puzzlelist_cb_init: puzzlelist: "+puzzlelist,1);
		_pb_totalPuzz = puzzlelist.length;
		if(_pb_totalPuzz === 0) {
			// have puzzlelist, but there are no puzzles in the system
			_pb_log("_pb_get_puzzle_cbs_init: no puzzles in puzzlelist, saving store",1);
			_pb_puzzstore.save({onComplete: _pb_puzzstore_save_done_init, onError: _pb_puzzstore_save_failed_init});
		} else {
			_pbrest_get("puzzles/*",_pb_get_puzzles_cb_init);
		}
	}
    
	// 2.b.2 the array of puzzles we requested has arrived. process them one by one.
	function _pb_get_puzzles_cb_init(puzzles, ioArgs) {
		_pb_log("_pb_get_puzzles_cb_init: received "+puzzles.length+" puzzles",1);
		for (var i in puzzles){
			var puzzle = puzzles[i];
			_pb_get_puzzle_cb_init(puzzle, ioArgs);
		}
	}

	// 2.b.2.a have a puzzle, add to store, increment arrival counter, and save store once all are arrived
	function _pb_get_puzzle_cb_init(puzzle, ioArgs) {
		_pb_log("_pb_get_puzzle_cb_init: puzzle["+puzzle.id+"] "+puzzle.name,1);
		_pb_puzzstore.newItem(puzzle);
		_pb_puzzArrivalCounter++;
		if (_pb_puzzArrivalCounter == _pb_totalPuzz){
			// we have all the puzzles ? (TODO fix this to actually check if this is true!)
			_pb_log("_pb_get_puzzle_cb_init: saving store",1);
			_pb_puzzstore.save({onComplete: _pb_puzzstore_save_done_init, onError: _pb_puzzstore_save_failed_init});
		}
	}
    

	// 2.b.3.a. puzzstore has all puzzles, save successful
	// proceed to phase 3 if 2.c is complete
	function _pb_puzzstore_save_done_init() {
	    _pb_log("_pb_puzzstore_save_done_init()",1);
	    _pb_puzzstore_init_complete = 1;
	    if(_pb_solverstore_init_complete > 0) {
		_pb_log("_pb_puzzstore_save_done_init: going to _pb_init_phase3()",1);
		_pb_init_phase3();
	    } else {
		_pb_log("_pb_puzzstore_save_done_init: deferring phase3 to _pb_solverstore_save_done_init()",1);
	    }
	}
    
	// 2.b.3.b. puzzstore has all puzzles, save failed!
	function _pb_puzzstore_save_failed_init() {
		_pb_log("_pb_puzzstore_save_failed_init: failed!!! (NOT IMPLEMENTED)",1);
		// todo -- handle this
		//_pb_init_phase3();
		_pb_cb_error("failed to store puzzles in Dojo puzzle store");
	}
    
	// 2.c.1 have solvers (solverlist), request each solver
	function _pb_get_solverlist_cb_init(solverlist, ioArgs){
		_pb_log("_pb_get_solverlist_cb_init(): solverlist: "+solverlist,1);
		_pb_totalSolvers = solverlist.length;
		if(_pb_totalSolvers === 0) {
			// have solverlist, but there are no solvers in the system
			_pb_log("_pb_get_solverlist_cb_init: no solvers in solverlist, saving store",1);
			_pb_solverstore.save({onComplete: _pb_solverstore_save_done_init, onError: _pb_solverstore_save_failed_init});
		} else {
			_pbrest_get("solvers/*", _pb_get_solvers_cb_init);
		}
	}

	// 2.c.2 the array of solvers we requested has arrived. process them one by one.
	function _pb_get_solvers_cb_init(solvers, ioArgs) {
		_pb_log("_pb_get_solvers_cb_init: received "+solvers.length+" solvers",1);
		for (var i in solvers) {
			var solver = solvers[i];
			_pb_get_solver_cb_init(solver, ioArgs);
		}
	}

	// 2.c.2.a have a solver, add to store, increment arrival counter, and save store once all are arrived
	function _pb_get_solver_cb_init(solver, ioArgs) {
	    _pb_log("_pb_get_solver_cb_init: solver["+solver.id+"] "+solver.name,1);
	    _pb_solverstore.newItem(solver);
	    _pb_solverArrivalCounter++;
	    if (_pb_solverArrivalCounter == _pb_totalSolvers){
		// we have all the solvers ? (TODO fix this to actually check if this is true!)
		_pb_log("_pb_get_solver_cb_init: saving store",1);
		_pb_solverstore.save({onComplete: _pb_solverstore_save_done_init, onError: _pb_solverstore_save_failed_init});
	    }
	}

	// 2.c.3.a. solverstore has all solvers, save successful
	// proceed to phase 3 if 2.b is complete
	function _pb_solverstore_save_done_init() {
	    _pb_log("_pb_solverstore_save_done_init()",1);
	    _pb_solverstore_init_complete = 1;
	    if(_pb_puzzstore_init_complete > 0) {
		_pb_log("_pb_solverstore_save_done_init: going to _pb_init_phase3()",1);
		_pb_init_phase3();
	    } else {
		_pb_log("_pb_solverstore_save_done_init: deferring phase3 to _pb_puzzstore_save_done_init()",1);
	    }
	}
    
	// 2.c.3.b. solverstore has all solvers, save failed!
	function _pb_solverstore_save_failed_init() {
		_pb_log("_pb_solverstore_save_failed_init: failed!!! (NOT IMPLEMENTED)",1);
		//_pb_init_phase3();
		_pb_cb_error("failed to store solvers in Dojo solver store");
	}
    
    
	// 3. have all puzzles in active puzzstore and all the solvers in active solverstore
	// wait for roundlist to arrive if they haven't already, 
	// then fire off _pb_cb_add_round callback
	function _pb_init_phase3() {
		_pb_log("_pb_init_phase3()",1);
		if(!_pb_roundlist) {
			// try again in a bit
			_pb_log("_pb_init_phase3: no roundlist yet, waiting...",1);
			setTimeout(_pb_init_phase3, 1000);
		} else if (!_pb_solverstore){
			//tray again in a bit.
			_pb_log("_pb_init_phase3: no solverlist yet, waiting...",1);
			setTimeout(_pb_init_phase3, 1000);
		} else {
			_pb_log("_pb_init_phase3: have roundlist, calling _pb_cb_add_round for each round. roundlist=["+_pb_roundlist+"]",1);
			for (var i in _pb_roundlist){
				var roundname = _pb_roundlist[i];
				_pb_log("_pb_init_phase3: firing off _pb_cb_add_round callback for "+roundname,1);
				_pb_cb_add_round(roundname);
			}
			_pb_log("_pb_init_phase3: have lists, calling _pb_cb_init_complete",1);
			_pb_cb_init_complete();
		}
	}
    
	function _pb_log(msg, lvl) {
		if (!lvl || lvl <= debug_lvl){
			console.log(msg);
		}
	}
    
    return {
	/////////////////////////////////////////////////////////////////////////////////
	// API Functions
	/////////////////////////////////////////////////////////////////////////////////
	pb_set_config: function(meteor_http_host, meteor_version_channel, pbrest_root) {
	    _pb_log("pb_set_config("+meteor_http_host+", "+meteor_version_channel+", "+pbrest_root+")");
	    _pb_config.meteor_http_host = meteor_http_host;
	    _pb_config.meteor_version_channel = meteor_version_channel;
	    _pb_config.pbrest_root = pbrest_root;
	},
	
	pb_init: function(cb_init_complete, cb_add_round, cb_update_puzzle, 
		cb_received_updated_part, cb_update_solver, cb_error, cb_warning, 
		cb_connection_status, cb_connection_mode,filter_version_diff) {
	    _pb_cb_init_complete = cb_init_complete;
	    _pb_cb_add_round = cb_add_round;
	    _pb_cb_update_puzzle = cb_update_puzzle;    
	    _pb_cb_received_updated_part = cb_received_updated_part;
		_pb_cb_update_solver = cb_update_solver;
	    _pb_cb_error = cb_error;
	    _pb_cb_warning = cb_warning;
	    _pb_cb_connection_status = cb_connection_status;
	    _pb_cb_connection_mode = cb_connection_mode;
		_pb_filter_version_diff = filter_version_diff;
	    
	    // kick-off initialization process
	    _pb_init();
		
	    return {puzzstore: _pb_puzzstore, solverstore: _pb_solverstore};
	},
	
	pb_log: _pb_log,

	pb_puzzstore: _pb_puzzstore,

	pb_solverstore: _pb_solverstore,
	
	pb_create_round: function(roundid) {
			var nodata = new Object();
			_pbrest_post("rounds/"+roundid, 
				nodata, 
				_pb_create_round_cb, 
				function(returndata){_pb_cb_warning(returndata.error)});
	},
	
	pb_meteor_reconnect_stream: function() {
		_pb_log("pb_meteor_reconnect_stream: disconnecting and reconnecting in stream mode");
		Meteor.disconnect();
		Meteor.mode = 'stream';
		Meteor.connect();
		//Meteor.reset();
		_pb_cb_connection_mode(Meteor.mode);
	},
};
});
