
define([
	   "../js/pb-meteor-rest-client.js",
	   "dojo/parser", 
	   "dojo/_base/connect",
	   "dojo/_base/lang",
	   "dojo/_base/array",
	   "dojo/_base/window",
	   "dijit/Dialog", 
	   "dijit/form/Button", 
	   "dojo/dnd/Source",
	   "dojo/topic",
	   "dojo/dom",
	   "dojo/dom-construct",
	   "dojo/dom-style",
	   "dojo/domReady!",
       ], 
    function(pbmrc, parser, connect, lang, array, win, dialog, formbutton, Source, topic, dom, domconstruct, domstyle) {

	var puzzstore; // IFWS which will be returned from pbmrc.pb_init()
	var solverstore; // IFWS which will be returned from pbmrc.pb_init()
	var update_solver_store; // function which will be returned from pbmrc.pb_init()
	
	var add_solver_ui_handler_connection;
	var remove_solver_ui_handler_connection;
	var update_solver_ui_handler_connection;
	var add_puzz_ui_handler_connection;
	var remove_puzz_ui_handler_connection;
	var update_puzz_ui_handler_connection;
	
	var poolBox;
	var puzzBoxes;
	var status_button;
	var meteor_status;
	var meteor_mode;

	var solved_answer_filter='*';
	
	var roundlist = new Array();
	roundlist.push("All");

	//disable copying from Sources (i.e. only allow move)
	lang.extend(Source, {copyState: function(keyPressed,self) {return false;}});

	function init_complete_cb() {
	    // remove the little waitDiv notice
	    win.body().removeChild(dom.byId("waitDiv"));
	    poolBox = new Source(dom.byId("poolcontainer"));
	    poolBox.singular=true;
	    //hooks up our listeners
	    pbmrc.pb_log("init_complete_cb(): enabling connection handlers");
	    enable_store_ui_handlers();
	    
	    pbmrc.pb_log("init_complete_cb(): adding puzzleboxes");
	    puzzBoxes = new Array(); 
		puzzstore.fetch({
			onItem: function(item){
				puzzBoxes[puzzstore.getValue(item,"name")] = new Source(create_puzzle_node(item));
				puzzBoxes[puzzstore.getValue(item,"name")].singular=true;
				var node = puzzBoxes[puzzstore.getValue(item,"name")].node;
				if (puzzstore.getValue(item,"answer") != "" && puzzstore.getValue(item,"status") == "Solved"){
					//this puzzle is already solved, so hide it.
					domstyle.set(node, "display", "none");	
				}
				dom.byId("puzzles_layout").appendChild(node);
			}
		});
	    
		pbmrc.pb_log("init_complete_cb(): adding solvers");
		solverstore.fetch({
			onItem: function(item){
				var node = create_solver_node(item);
				if (solverstore.getValue(item,"puzz") == ""){
					poolBox.insertNodes(false,[node]);
				}else{
					var box = puzzBoxes[solverstore.getValue(item,"puzz")];
					if (box){
						box.insertNodes(false,[node]);
					}else{
						poolBox.insertNodes(false,[node]);
					}
				}
			}
		});
	    pbmrc.pb_log("init_complete_cb(): init complete");
	}
	
	function enable_store_ui_handlers(){
		add_solver_ui_handler_connection = connect.connect(solverstore,"onNew",add_solver_ui);
		remove_solver_ui_handler_connection = connect.connect(solverstore,"onDelete",remove_solver_ui);
		update_solver_ui_handler_connection = connect.connect(solverstore,"onSet",update_solver_ui);
		add_puzz_ui_handler_connection = connect.connect(puzzstore,"onNew",add_puzz_ui);
		remove_puzz_ui_handler_connection = connect.connect(puzzstore,"onDelete",remove_puzz_ui);
		update_puzz_ui_handler_connection = connect.connect(puzzstore,"onSet",update_puzz_ui);
	}
	
	function disable_store_ui_handlers(){
		connect.disconnect(add_solver_ui_handler_connection);
		connect.disconnect(remove_solver_ui_handler_connection);
		connect.disconnect(update_solver_ui_handler_connection);
		connect.disconnect(add_puzz_ui_handler_connection);
		connect.disconnect(remove_puzz_ui_handler_connection);
		connect.disconnect(update_puzz_ui_handler_connection);
	}
	
	function create_solver_node(item){
		return domconstruct.create("div", {class: "solver", id: "solver_div_"+solverstore.getValue(item,"name"), innerHTML: solverstore.getValue(item,"name")});
	}
	
	function create_puzzle_node(item){
	    return domconstruct.create("div", {class: "puzzle_container", id: "puzzle_div_"+puzzstore.getValue(item,"name"), innerHTML: puzzstore.getValue(item,"name")});
	}
	
	function dropped_on_puzz(source, nodes, copy, target){
	    //note this only works if we move one at a time (hence Source.singular is set)
	    var moved_node_name = nodes[0].id;
	    var splitsolver = moved_node_name.split('_');
	    var solver = splitsolver[2];
		
	    //need to translate target source name to DB puzzle name
	    var target_source_name = target.node.id;
	    var puzz;
	    if (target_source_name == "poolcontainer"){
		//the null puzzle
		puzz = "";
	    }else{
		var splitpuzz = target_source_name.split('_');
		puzz = splitpuzz[2];
	    }

		pbmrc.pb_log("dropped_on_puzz(): solver "+solver+" dropped on "+puzz);
		// update client's changes in the store.
		solverstore.fetchItemByIdentity({
			identity: solver,
			onItem: function(item) {
				disable_store_ui_handlers()
				solverstore.setValue(item,"puzz",puzz);
				solverstore.save({onError: error_cb});
				enable_store_ui_handlers()
			}
		});
	}
	
	function add_solver_ui(item, parentinfo){		
		pbmrc.pb_log("add_solver_ui()");
		if (solverstore.getValue(item,"puzz") == ""){
			var node = create_solver_node(item);
			poolBox.insertNodes(false,[node]);
		}else{
			error_cb("Solver "+solverstore.getValue(item,"name")+" was added, but is already working on a puzzle?!");
		}
	}
	
	function remove_solver_ui(item){
		pbmrc.pb_log("remove_solver_ui()");
		
		if (solverstore.getValue(item,"puzz")==""){
			poolBox.delItem(solverstore.getValue(item,"name"))
		}else{
			puzzBoxes[solverstore.getValue(item,"puzz")].delItem(solverstore.getValue(item,"name"));
		}
	}
	
	function update_solver_ui(item, attribute, oldValue, newValue){
		pbmrc.pb_log("update_solver_ui(): name="+solverstore.getValue(item,"name")+" attribute="+attribute+" oldValue="+oldValue+" newValue="+newValue);
		if (attribute == "puzz"){
			if (newValue == ""){
			    poolBox.insertNodes(false,[dom.byId("solver_div_"+solverstore.getValue(item,"name"))]);
			    poolBox.sync();				
			}else{
				puzzBoxes[newValue].insertNodes(false, [dom.byId("solver_div_"+solverstore.getValue(item,"name"))]);
				puzzBoxes[newValue].sync();
			}
			if (oldValue == ""){
				poolBox.delItem("solver_div_"+solverstore.getValue(item,"name"));
				poolBox.sync();
			}else{
				puzzBoxes[oldValue].delItem("solver_div_"+solverstore.getValue(item,"name"));
				puzzBoxes[oldValue].sync();
			}
		}
	}
	
	function add_puzz_ui(item, parentinfo){
		pbmrc.pb_log("add_puzz_ui()");
		
		if (puzzstore.getValue(item,"answer") == "" || puzzstore.getValue(item,"status") != "Solved"){
		    puzzBoxes[puzzstore.getValue(item,"name")] = new Source(create_puzzle_node(item));					
		    puzzBoxes[puzzstore.getValue(item,"name")].singular = true;
		    dom.byId("puzzles_layout").appendChild(puzzBoxes[puzzstore.getValue(item,"name")].node);
		}
	}
	
	function remove_puzz_ui(item){
	    pbmrc.pb_log("remove_puzz_ui()");
	    dom.byId("puzzles_layout").removeChild(puzzBoxes[puzzstore.getValue(item,"name")].node);
	    pbmrc.pb_log("successfully removed node");
	}
	
	function update_puzz_ui(item, attribute, oldValue, newValue){
		pbmrc.pb_log("update_puzz_ui(): name="+puzzstore.getValue(item,"name")+" attribute="+attribute+" oldValue="+oldValue+" newValue="+newValue);
		if ((attribute == "status" && newValue == "Solved" && puzzstore.getValue(item,"answer") != "" && oldValue != "Solved")||
		    (attribute == "answer" && newValue != "" && oldValue == "" && puzzstore.getValue(item,"status") == "Solved")){
		    //this represents a puzzle switched to solved, and with a non-null answer
		    domstyle.set(puzzBoxes[puzzstore.getValue(item,"name")].node, "display", "none");
		}else if((attribute == "status" && oldValue == "Solved" && newValue != "Solved") ||
			 (attribute == "answer" && oldValue != "" && newValue == "")){
		    //this represents a puzzle switched from solved to unsolved
		    domstyle.set(puzzBoxes[puzzstore.getValue(item,"name")].node, "display", "block");
		}
	}
	
	function roundlist_update_cb(my_roundlist) {
		//don't care.
	}
	
	function add_round_cb(roundname) {
		//don't care.
	}

	
	function puzzle_update_cb() {
		pbmrc.pb_log("puzzle_update_cb(): does nothing.",2);
	}
	
	function solver_update_cb(){
		pbmrc.pb_log("solver_update_cb(): does nothing.",2);
	}
	
	
	function received_updated_part_cb(store, appid, key, value) {
	    pbmrc.pb_log("received_updated_part_cb: store="+store+" appid="+appid+" key="+key+" value="+value);
	}


	function error_cb(msg) {
	    win.body().removeChild(dom.byId("waitDiv"));
		win.body().appendChild(domconstruct.create("p",{innerHTML: "I'm sorry, a catastrophic error occurred: "}));
		win.body().appendChild(domconstruct.create("p",{innerHTML: msg}));
		win.body().appendChild(domconstruct.create("p",{innerHTML: "Perhaps jcrandall@alum.mit.edu or jcbarret@alum.mit.edu could help?"}));
	}
	
	function warning_cb(msg) {
	    pbmrc.pb_log("warning_cb: creating warning dialog with msg="+msg);
	    warning_dialog = new dialog({
		    title: "Warning",
		    content: msg,
		    style: "width: 300px"
		});
		warning_dialog.show();
	}
	
	function meteor_conn_status_cb(status, detail) {
	    pbmrc.pb_log("meteor_conn_status_cb: status="+status+" detail="+detail);
	    //receiving, ready, timeout, loading, eof
	    meteor_status = status;
	    update_status_button();
	}
	
	
	function meteor_conn_mode_cb(mode) {
	    pbmrc.pb_log("meteor_conn_mode_cb: mode="+mode);
	    //stream, xhrinteractive, iframe, serversent
	    //poll, smartpoll, longpoll
	    if(mode == "stream" || mode == "xhrinteractive" || mode == "iframe" || mode == "serversent") {
		meteor_mode = "stream";
	    } else {
		meteor_mode = "poll"
		    }
	    update_status_button();
	}
	
	function update_status_button() {
	    pbmrc.pb_log("update_status_button() meteor_mode="+meteor_mode+" meteor_status="+meteor_status);
	    if(meteor_status == "receiving") { 
		if(meteor_mode=="stream") {
		    status_button.set("iconClass","button-status-green");
		    status_button.set("label","Streaming");
		    status_button.set("disabled",true);
		} else {
		    status_button.set("iconClass","button-status-blue");
		    status_button.set("label","Polling");
		    status_button.set("disabled",false);
		}
	    } else {
		if(meteor_status == "loading") {
		    status_button.set("iconClass","button-status-red");
		    status_button.set("label","Loading");
		    status_button.set("disabled",false);
		} else if(meteor_status == "timeout") {
		    status_button.set("iconClass","button-status-red");
		    status_button.set("label","Reloading");
		    status_button.set("disabled",false);
		} else if(meteor_status == "ready") {
		    if(meteor_mode=="stream") {
			status_button.set("iconClass","button-status-yellow");
			status_button.set("label","Stream Ready");
			status_button.set("disabled",false);
		    } else {
			status_button.set("iconClass","button-status-orange");
			status_button.set("label","Polling Ready");
			status_button.set("disabled",false);
		    }
		} else if(meteor_status == "eof") {
		    status_button.set("iconClass","button-status-red");
		    status_button.set("label","Asynchronous stream disrupted, you may need to reload page.");
		    status_button.set("showLabel",true);
		    status_button.set("disabled",false);
		} else {
		    pbmrc.pb_log("update_status_button: unknown status="+meteor_status);
		    status_button.set("label","Meteor status error");
		    status_button.set("showLabel",true);
		    status_button.set("disabled",false);
		}
	    }    
	}
	
	var is_addpuzzle_patt = /^puzzles\/[^\/]*\/$/;
	var is_answerstatus_patt = /^puzzles\/[^\/]*\/(answer|status)$/;
	var is_solvers_patt = /^solvers/;
	var is_any_version_patt = /^version/;

	function version_diff_filter(diff){
	    // N.B. all pbmrcs must listen to version!
	    pbmrc.pb_log("version_diff_filter()")
	    return array.filter(diff, function(item){
				    return (is_any_version_patt.test(item) ||
					    is_addpuzzle_patt.test(item) || 
					    is_solvers_patt.test(item) || 
					    is_answerstatus_patt.test(item));
				});
	}
	
	return {
		
		my_init: function() {
	    
			pbmrc.pb_log("my_init: creating status indicator / button");
			status_button = new formbutton({
				label: "Status", 
				onClick: pbmrc.pb_meteor_reconnect_stream, 
				showLabel: true,
				iconClass: "button-status-red",
			});
			pbmrc.pb_log("my_init: attaching status button to container");
			dom.byId("statuscontainer").appendChild(status_button.domNode);
	    
			pbmrc.pb_log("my_init: calling pbmrc.pb_init");
		    var ret = pbmrc.pb_init(init_complete_cb, add_round_cb, 
				puzzle_update_cb, received_updated_part_cb, solver_update_cb, 
				error_cb, warning_cb, meteor_conn_status_cb, meteor_conn_mode_cb,version_diff_filter);
				
		    puzzstore = ret.puzzstore;
		    solverstore = ret.solverstore;
			topic.subscribe("/dnd/drop",dropped_on_puzz);
		},	
	};
		
    });


