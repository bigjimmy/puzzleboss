
define([
     "../js/pb-meteor-rest-client.js",
     "dojo/parser", 
     "dojo/_base/connect",
     "dijit/Dialog", 
     "dijit/form/Button", 
     "dijit/form/TextBox",
	 "dojo/dnd/Source",
	 "dojo/topic",
     "dojo/dom",
	 "dojo/dom-construct",
     "dojo/domReady!",
     ], 
    function(pbmrc, parser, connect, dialog, formbutton, formtextbox, Source, topic, dom, domConstruct, domready) {

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
	var puzzBoxes = new Array();
	var puzzBoxDivs = new Array();
	var waitDiv;
	var status_button;
	var meteor_status;
	var meteor_mode;
	var my_editable;

	var solved_answer_filter='*';
	
	var roundlist = new Array();
	roundlist.push("All");
	
	function init_complete_cb() {
	    pbmrc.pb_log("init_complete_cb()");	
	    // remove the little waitDiv notice
	    dom.byId("puzzlecontainer").removeChild(waitDiv);
		poolBox = new Source(dom.byId("poolcontainer"));
		//hooks up our listeners
		pbmrc.pb_log("init_complete_cb(): enabling connection handlers");
		enable_store_ui_handlers();
		
		pbmrc.pb_log("init_complete_cb(): adding puzzleboxes");
		puzzBoxDivs = new Array();
		puzzBoxes = new Array(); 
		puzzstore.fetch({
			onItem: function(item){
				if (item.answer == ""){
					puzzBoxDivs[item.name] = domConstruct.create("div", {class: "container", id: item.name});
					puzzBoxDivs[item.name].appendChild(domConstruct.create("p",{innerHTML: item.name}));
					puzzBoxes[item.name] = new Source(puzzBoxDivs[item.name]);					
					dom.byId("puzzlecontainer").appendChild(puzzBoxDivs[item.name]);
				}
			}
		});
		
		pbmrc.pb_log("init_complete_cb(): adding solvers");
		solverstore.fetch({
			onItem: function(item){
				var node = create_solver_node(item);
				if (item.puzz == ""){
					poolBox.insertNodes(false,[node]);
				}else{
					puzzBoxes[item.puzz].insertNodes(false,[node]);
				}
			}
		});
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
		return domConstruct.create("div", {class: "solver", id: "solver_div_"+item.name, innerHTML: item.name});
	}
	
	function dropped_on_puzz(source, nodes, copy, target){
		//Note that this only works if there's exactly one node being dnd'd. 
		//TODO: perhaps our interface should be restricted to moving one at a time?
		var solver = nodes[0].innerHTML;
		var puzz = target.node.id;
		
		if (puzz == "poolcontainer"){
			//the null puzzle
			puzz = "";
		}

		pbmrc.pb_log("dropped_on_puzz(): solver "+solver+" is now in "+puzz);
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
		if (item.puzz == ""){
			var node = create_solver_node(item);
			poolBox.insertNodes(false,[node]);
		}else{
			error_cb("Solver "+item.name+" was added, but is already working on a puzzle?!");
		}
	}
	
	function remove_solver_ui(item){
		pbmrc.pb_log("remove_solver_ui()");
		
		if (item.puzz==""){
			poolBox.delItem(item.name)
		}else{
			puzzBoxes[item.puzz].delItem(item.name);
		}
	}
	
	function update_solver_ui(item, attribute, oldValue, newValue){
		pbmrc.pb_log("update_solver_ui(): name="+item.name+" attribute="+attribute+" oldValue="+oldValue+" newValue="+newValue);
		if (attribute == "puzz"){
			if (newValue == ""){
				poolBox.insertNodes(false, [dom.byId("solver_div_"+item.name)]);
				poolBox.sync();				
			}else{
				puzzBoxes[newValue].insertNodes(false, [dom.byId("solver_div_"+item.name)]);
				puzzBoxes[newValue].sync();
			}
			if (oldValue == ""){
				poolBox.delItem("solver_div_"+item.name);
				poolBox.sync();
			}else{
				puzzBoxes[oldValue].delItem("solver_div_"+item.name);
				puzzBoxes[oldValue].sync();
			}
		}
	}
	
	function add_puzz_ui(item, parentinfo){
		pbmrc.pb_log("add_puzz_ui()");
		
		if (item.answer == ""){
			puzzBoxDivs[item.name] = domConstruct.create("div", {class: "container", id: item.name});
			puzzBoxDivs[item.name].appendChild(domConstruct.create("p",{innerHTML: item.name}));
			puzzBoxes[item.name] = new Source(puzzBoxDivs[item.name]);					
			dom.byId("puzzlecontainer").appendChild(puzzBoxDivs[item.name]);
		}
	}
	
	function remove_puzz_ui(item){
		pbmrc.pb_log("remove_puzz_ui()");
		
		dom.byID("puzzlecontainer").removeChild(puzzBoxDivs[item.name]);
	}
	
	function update_puzz_ui(item, attribute, oldValue, newValue){
		pbmrc.pb_log("update_puzz_ui()");
		if (attribute == "status" && newValue == "Solved" && item.answer != "" && oldValue != "Solved"){
			//this represents a puzzle switched to solved, and with a non-null answer
			delete_puzz_ui(item);
		}else if(attribute == "status" && oldValue == "Solved" && newValue != "Solved"){
			//this represents a puzzle switched from solved to unsolved
			add_puzz_ui(item);
		}
	}
	
	function roundlist_update_cb(my_roundlist) {
		//don't care.
	}
	
	function add_round_cb(roundname) {
		//don't care.
	}

	
	function puzzle_update_cb() {
		pbmrc.pb_log("puzzle_update_cb(): does nothing.");
	}
	
	function solver_update_cb(){
		pbmrc.pb_log("solver_update_cb(): does nothing.");
	}
	
	
	function received_updated_part_cb(store, appid, key, value) {
	    pbmrc.pb_log("received_updated_part_cb: store="+store+" appid="+appid+" key="+key+" value="+value);
	}


	function error_cb(msg) {
	    dom.byId("puzzlecontainer").removeChild(waitDiv);
		dom.byId("puzzlecontainer").appendChild(domConstruct.create("p",{innerHTML: "I'm sorry, a catastrophic error occurred: "}));
		dom.byId("puzzlecontainer").appendChild(domConstruct.create("p",{innerHTML: msg}));
		dom.byId("puzzlecontainer").appendChild(domConstruct.create("p",{innerHTML: "Perhaps jcrandall@alum.mit.edu or jcbarret@alum.mit.edu could help?"}));
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
	
	function _display_all(){
		for (var i in roundlist){
			var roundname = roundlist[i];
			if (roundname != "All"){
				tpdivs[roundname].style.display = 'none';
			}else{
				tpdivs[roundname].style.display = 'block';
			}
		}
	}
	
	
	function _updateRoundsVsAll(){
		var toggled = dom.byId("roundsvsall").checked;
		if (toggled == true){
			 pbmrc.pb_log("displaying rounds");
			_display_rounds();
		}else{
			 pbmrc.pb_log("displaying all");
			_display_all();
		}
	}
	
	return {
		updateHideSolved: function() {
			_updateHideSolved();
		},

		updateRoundsVsAll: function(){
			_updateRoundsVsAll();
		},
		
		my_init: function(editable) {
			my_editable = editable;
			pbmrc.pb_log("my_init()");
			//please wait
			waitDiv = domConstruct.create("div")
			waitDiv.innerHTML="<b>Please wait, while data loads. (This could take a while!)</b></br>";
			dom.byId("puzzlecontainer").appendChild(waitDiv);
	    
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
				error_cb, warning_cb, meteor_conn_status_cb, meteor_conn_mode_cb);
				
		    puzzstore = ret.puzzstore;
		    solverstore = ret.solverstore;
			topic.subscribe("/dnd/drop",dropped_on_puzz);
		},	
	};
		
    });


