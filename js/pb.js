
define([
     "../js/pb-meteor-rest-client.js",
     "dojo/parser", 
     "dojo/_base/connect",
     "dojo/_base/array",
     "dojo/_base/window",
     "dijit/TitlePane", 
     "dojox/grid/EnhancedGrid", 
     "dojox/grid/cells",
     "dijit/Dialog", 
     "dijit/form/Button", 
     "dijit/form/TextBox",
     "dojo/dom",
     "dojo/dnd/Source",
     "dojo/domReady!"
       ], 
    function(pbmrc, parser, connect, array, win, titlepane, enhancedgrid, cells, dialog, formbutton, formtextbox, dom, dndsource) {

	var puzzstore; // will be returned from pbmrc.pb_init()
	var status_button;
	var meteor_status;
	var meteor_mode;
	var my_editable;
	
	var solved_answer_filter='*';
	
	var roundlist = new Array();
	roundlist.push("All");
	
	var grid = new Array();
	var tp = new Array();
	var griddivs = new Array();
	var tpdivs = new Array();
	
	function fixedwidthFormatter(value){
	    return "<span class='fixedwidthformat'>"+value+"</span>";
	}
	
	function smallfontFormatter(value){
	    return "<span style='font-size: 12'>"+value+"</span>";
	}
	
	function starFormatter(value){
	    switch(value){
	    case "1":
		return "&#9733;";
	    case "2":
		return "&#9733;&#9733;";
	    case "3":
		return "&#9733;&#9733;&#9733;";
	    }
	}
	
	function statusFormatter(value){
		switch(value){
			case "New":
			return "<span style='font-size: 12'>NEW</span>";
			case "Being worked":
			return "<span style='font-size: 12'>WORK</span>";
			case "Needs eyes":
			return "<span style='font-size: 12'>EYES</span>";
			case "Solved":
			return "<span style='font-size: 12'>SOLVED</span>";
			default:
			return "<span style='font-size: 12'>ERROR</span>";
		};
	}
	
	function create_new_round_ui(roundname) {
	    pbmrc.pb_log("create_new_round_ui: creating round ui for "+roundname);
	    // create a new grid:
	
		var puzzlayout = [
				     { field: 'round', hidden: true },
				     { field: 'linkid', width: "12%", name: "Puzzle", formatter: smallfontFormatter},
				     { field: 'status', width: "6%", name: "Status", editable: my_editable, formatter: statusFormatter,
				       type: cells.Select, options: ['New', 'Being worked', 'Needs eyes', 'Solved']},
				     { field: 'answer', width: "12%", name: "Answer", editable: my_editable, formatter: fixedwidthFormatter},
				     { field: 'xyzloc', width: "10%", name: "Location", editable: my_editable, formatter: smallfontFormatter },
				     { field: 'cursolvers', width: "20%", name:"Solvers", formatter:smallfontFormatter},
				     { field: 'comments', width: "40%", name: "PB Notes", editable: my_editable, formatter: smallfontFormatter}
				     ];
	
	    grid[roundname] = new enhancedgrid({
		    store: puzzstore,
		    clientSort: true,	
		    structure: puzzlayout,
		    escapeHTMLInData: false, 
		    autoHeight: true,
		    updateDelay: 0,
		});						
	    //grid[roundname].messagesNode = dojo.byId("gridMessages");
	    
	    
	    griddivs[roundname] = document.createElement("div");
	    griddivs[roundname].style.padding="0px";
	    //griddivs[roundname].style.width="100%";
	    griddivs[roundname].appendChild(grid[roundname].domNode);
	    
	    
	    //titlepane
	    tp[roundname] = new titlepane({ 
		    title:roundname, 
		    content: griddivs[roundname], 
		    open:false
		});
	    
	    tp[roundname].containerNode.style.padding="0px";
	    
	    tpdivs[roundname] = document.createElement("div");
	    tpdivs[roundname].appendChild(tp[roundname].domNode);
	    dom.byId("puzzlecontainer").appendChild(tpdivs[roundname]);
	    // Call startup, in order to render the grid:
	    grid[roundname].startup();
	    connect.connect(tp[roundname],"toggle",grid[roundname], "update");
	}
	
	function apply_round_filters() {
	    pbmrc.pb_log("apply_round_filters()");
	    for (var i in roundlist){
		var roundname = roundlist[i];
		if (roundname != "All"){
		    pbmrc.pb_log("apply_round_filters: calling grid["+roundname+"].filter({round: "+roundname+", answer:  "+solved_answer_filter+"}, true); with rowCount="+grid[roundname].rowCount,3);
		    grid[roundname].filter({round: roundname, answer: solved_answer_filter}, true);
		}else{
		    pbmrc.pb_log("apply_round_filters: calling grid["+roundname+"].filter({answer:  "+solved_answer_filter+"}, true); with rowCount="+grid[roundname].rowCount,3);
		    grid[roundname].filter({answer: solved_answer_filter},true);
		}
	    }
	    
	}

	
	function init_complete_cb() {
	    pbmrc.pb_log("init_complete_cb()",2);	
	    //apply_round_filters();
	    // remove the little waitDiv notice
	    win.body().removeChild(dom.byId("waitDiv")); 
	    _updateHideSolved();
	    _updateRoundsVsAll();
	    pbmrc.pb_log("init_complete_cb(): init complete");
	}
	
	function add_round_cb(roundname) {
	    create_new_round_ui(roundname);
		roundlist.push(roundname);
		apply_round_filters();
		_updateRoundsVsAll();
	}
	
	
	function puzzle_update_cb() {
	    pbmrc.pb_log("puzzle_update_cb");
	    apply_round_filters();
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
	
	var is_any_puzzles_patt = /^puzzles/;
	var is_any_version_patt = /^version/;
	var is_any_rounds_patt = /^rounds/;
	function version_diff_filter(diff){
	    // N.B. all pbmrcs must listen to version!
		return array.filter(diff, function(item){
			return is_any_version_patt.test(item) || is_any_puzzles_patt.test(item) || is_any_rounds_patt.test(item);
		});
	}

	
	function _updateHideSolved(){
			var toggled = dom.byId("hidesolved").checked;
		    if (toggled == true){
				solved_answer_filter = '';
		    }else{
				solved_answer_filter = '*';
		 	}
			apply_round_filters();
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
	
	
	function _display_rounds(){
		for (var i in roundlist){
			var roundname = roundlist[i];
			if (roundname == "All"){
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
	    var ret = pbmrc.pb_init(init_complete_cb, add_round_cb, puzzle_update_cb, received_updated_part_cb, 
				    solver_update_cb, error_cb, warning_cb, meteor_conn_status_cb, meteor_conn_mode_cb,
					version_diff_filter);
	    puzzstore = ret.puzzstore;
	    create_new_round_ui("All");
	},
	};
		
    });


