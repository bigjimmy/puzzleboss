
define([
	   "../js/pb-meteor-rest-client.js",
	   "dojo/parser", 
	   "dojo/_base/connect",
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
    function(pbmrc, parser, connect, array, win, dialog, formbutton, Source, topic, dom, domconstruct, domstyle) {

	var puzzstore; // IFWS which will be returned from pbmrc.pb_init()
	var solverstore; // IFWS which will be returned from pbmrc.pb_init()
	
    var add_puzz_ui_handler_connection;
    var remove_puzz_ui_handler_connection;
    var update_puzz_ui_handler_connection;

	var status_button;
	var meteor_status;
	var meteor_mode;
	var my_editable;
	
	var summary = dom.byId("summary_layout");
	var roundboxes = new Array();

	var solved_answer_filter='*';

	function init_complete_cb() {
	    // remove the little waitDiv notice
	    win.body().removeChild(dom.byId("waitDiv"));

	    //hooks up our listeners
	    pbmrc.pb_log("init_complete_cb(): enabling connection handlers");
	    enable_store_ui_handlers();
	    
	    pbmrc.pb_log("init_complete_cb(): adding puzzles");
		puzzstore.fetch({
			onItem: function(item){
				add_puzz_ui(item);
			}
			});

	    pbmrc.pb_log("init_complete_cb(): init complete");		
	}
	
	function enable_store_ui_handlers(){
		add_puzz_ui_handler_connection = connect.connect(puzzstore,"onNew",add_puzz_ui);
		remove_puzz_ui_handler_connection = connect.connect(puzzstore,"onDelete",remove_puzz_ui);
		update_puzz_ui_handler_connection = connect.connect(puzzstore,"onSet",update_puzz_ui);
	}
	
	function disable_store_ui_handlers(){
		connect.disconnect(add_puzz_ui_handler_connection);
		connect.disconnect(remove_puzz_ui_handler_connection);
		connect.disconnect(update_puzz_ui_handler_connection);
	}

	function choose_status_image(item){
		var html_msg = "";
		var my_status = puzzstore.getValue(item,"status");
		if(my_status == "New"){
			html_msg = "<img src=\"../images/new_bang.jpg\" title='New'> ";
		}else if (my_status == "Being worked"){
			html_msg = "<img src=\"../images/work_gear.png\" title='Being worked'> ";
		}else if (my_status == "Needs eyes"){
			html_msg = "<img src=\"../images/eyes_sauron.jpg\" title='Needs eyes'> ";
		}else if (my_status == "Solved"){
			html_msg = "<img src=\"../images/solved_tick.png\" title='Solved'> ";
		}
		return html_msg;
	}
	
	function add_puzz_ui(item, parentinfo){
		pbmrc.pb_log("add_puzz_ui()");
		var name = puzzstore.getValue(item,"name");
		
		var puzzinfo = domconstruct.create("div", {id: "puzzleinfo_div_"+name});
		
		//the status image
		puzzinfo.appendChild(domconstruct.create("span", {id: "pi_statusimg_span_"+name, innerHTML: choose_status_image(item)}));
			
		//the Puzzle name
		var namespan = domconstruct.create("span", {id: "pi_name_span_"+name, class: "pi_name", innerHTML: name});
		if 	(puzzstore.getValue(item,"status") == "Solved"){
			domstyle.set(namespan,"color","#bbb");
		}
		puzzinfo.appendChild(namespan);
		
		//the answer 
		puzzinfo.appendChild(domconstruct.create("span", {id: "pi_answer_span_"+name, class: "pi_answer", innerHTML: puzzstore.getValue(item,"answer")}));			

		if (puzzstore.getValue(item,"answer") == ""){
			//links to spreadsheet and puzzle pages if answer unknown
			puzzinfo.appendChild(domconstruct.create("span",{id: "pi_links_span_"+name,
				innerHTML:"<a href='"+encodeURI(puzzstore.getValue(item,"gssuri"))+"' target='_blank'><img src='../images/spreadsheet.png' title='Spreadsheet'></a><a href='"+encodeURI(puzzstore.getValue(item,"uri"))+"' target='_blank'><img src='../images/puzzle.png' title='Spreadsheet'></a>"}));
	
		}
		
		roundboxes[puzzstore.getValue(item,"round")].appendChild(puzzinfo);
	}
	
	function remove_puzz_ui(item){
	    pbmrc.pb_log("remove_puzz_ui()");
		//TODO: this might not work??? Is the item the node itself?
		roundboxes[puzzstore.getValue(item,"round")].removeChild(item);
	    pbmrc.pb_log("successfully removed node");
	}
	
	function update_puzz_ui(item, attribute, oldValue, newValue){
		pbmrc.pb_log("update_puzz_ui(): name="+puzzstore.getValue(item,"name")+" attribute="+attribute+" oldValue="+oldValue+" newValue="+newValue);
		var name = puzzstore.getValue(item,"name");
		if (attribute == "status"){
			pbmrc.pb_log("looking for pi_statusmsg_span_"+name);
			dom.byId("pi_statusimg_span_"+name).innerHTML=choose_status_image(item);
			if (newValue == "Solved" && oldValue != "Solved"){
				domstyle.set(dom.byId("pi_name_span_"+name),"color","#bbb");
			}else if(newValue != "Solved" && oldValue == "Solved"){
				domstyle.set(dom.byId("pi_name_span_"+name),"color","#000");
			}
		} else if ( attribute == "answer"){
			dom.byId("pi_answer_span_"+name).innerHTML=puzzstore.getValue(item,"answer");				
			if (newValue == "" && oldValue != ""){
				//we'are deleting the answer, here, so reveal the solving links.
				domstyle.set(dom.byId("pi_links_span_"+name),"display","inline");
			}else if (newValue != "" && oldValue == ""){
				//we're inserting the answer, so hide the solving links
				domstyle.set(dom.byId("pi_links_span_"+name),"display","none");
			}
		}
	}
	
	function roundlist_update_cb(my_roundlist) {
		//don't care.
	}
	
	function add_round_cb(roundname) {
		pbmrc.pb_log("add_round_cb(): adding round "+roundname);
		roundboxes[roundname] = domconstruct.create("div", {class: "round_container", id: "round_div_"+roundname, innerHTML: "<h2>"+roundname+"</h2>"});
		summary.appendChild(roundboxes[roundname]);	
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
	var is_any_rounds_patt = /^rounds/;
	var is_answerstatus_patt = /^puzzles\/[^\/]*\/(answer|status)$/;
	var is_any_version_patt = /^version/;

	function version_diff_filter(diff){
	    // N.B. all pbmrcs must listen to version!
	    pbmrc.pb_log("version_diff_filter()")
	    return array.filter(diff, function(item){
				    return (is_any_version_patt.test(item) ||
					    is_addpuzzle_patt.test(item) || 
					    is_any_rounds_patt.test(item) || 
					    is_answerstatus_patt.test(item));
				});
	}
	
	return {
		
		my_init: function(editable) {
			my_editable = editable;
	    
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
		},	
	};
		
    });


