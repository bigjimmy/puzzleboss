
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
		var poolBox = new Source(dom.byId("poolcontainer"));
		add_puzzle_boxes();
		solverstore.fetch({
			onItem: function(item){
				if (item.puzz == ""){
					poolBox.insertNodes(false,item.id);
				}else{
					puzzBoxes[item.puzz].insertNodes(false,item.id);
				}
		 	}
		 });
	}
	
	function dropped_on_puzz(source, nodes, copy, target){
		update_solver_store(nodes[0].innerHTML,target.node.id);
		//Note that this only works if there's exactly one node being dnd'd. 
		//perhaps our interface should be restricted to moving one at a time?
	}
	
	function roundlist_update_cb(my_roundlist) {
	    //don't care.
	}
	
	function add_round_cb(roundname) {
		//don't care.
	}
	
	function add_puzzle_boxes(){
		pbmrc.pb_log("add_puzzle_boxes(): adding puzzle boxes");
		puzzBoxDivs = new Array();
		puzzBoxes = new Array(); 
		puzzstore.fetch({
			onItem: function(item){
				if (item.answer == ""){
					puzzBoxDivs[item.id] = domConstruct.create("div", {class: "container", id: item.id});
					puzzBoxDivs[item.id].appendChild(domConstruct.create("p",{innerHTML: item.id}));
					puzzBoxes[item.id] = new Source(puzzBoxDivs[item.id]);					
					dom.byId("puzzlecontainer").appendChild(puzzBoxDivs[item.id]);
				}
			}
		});
	}
	
	function puzzle_update_cb() {
		pbmrc.pb_log("puzzle_update_cb()");
		//we delete any div that belongs to a solved puzzle.
		for (var i in puzzBoxDivs){
			dom.byId("puzzlecontainer").removeChild(puzzBoxDivs[i]);
		}
		add_puzzle_boxes();
		
	    //pbmrc.pb_log("puzzle_update_cb");
	    //pbmrc.pb_log("puzzle_update_cb: applying round filters");	
	    //apply_round_filters();
	}
	
	function puzzle_part_update_cb(puzzle, key, value) {
	    pbmrc.pb_log("puzzle_part_update_cb: puzzle="+puzzle+" key="+key+" value="+value);
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
		        var ret = pbmrc.pb_init(init_complete_cb, roundlist_update_cb, add_round_cb, puzzle_update_cb, puzzle_part_update_cb, error_cb, warning_cb, 
				meteor_conn_status_cb, meteor_conn_mode_cb);
		        puzzstore = ret.puzzstore;
		        solverstore = ret.solverstore;
		        update_solver_store = ret.update_solverstore;
			topic.subscribe("/dnd/drop",dropped_on_puzz);
		},	
	};
		
    });


