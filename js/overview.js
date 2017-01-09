define([
	   "../js/pb-meteor-rest-client.js",
	   "dojo/parser", 
	   "dojo/_base/connect",
	   "dojo/_base/array",
	   "dojo/_base/window",
	   "dijit/Dialog", 
	   "dijit/form/Button",
	   "dijit/form/Select", 
           "dijit/form/TextBox",
	   "dojo/topic",
	   "dojo/dom",
	   "dojo/dom-construct",
	   "dojo/dom-class",
	   "dojo/domReady!",
       ], 
    function(pbmrc, parser, connect, array, win, dialog, formbutton, formselect, formtextbox, topic, dom, domconstruct, domclass) {

	var wall; // Masonry element
	var puzzstore; // IFWS which will be returned from pbmrc.pb_init()
	var solverstore; // IFWS which will be returned from pbmrc.pb_init()
	var remote_user;

	var add_puzz_ui_handler_connection;
	var remove_puzz_ui_handler_connection;
	var update_puzz_ui_handler_connection;
	var update_solver_ui_handler_connection;

	var status_button;
	var meteor_status;
	var meteor_mode;
	
	var summary = dom.byId("summary_layout");
	var roundboxes = new Array();

	var solved_answer_filter='*';
	
	var puzzle_popup_dialog = new dialog({class: "puzzle_popup_dialog", id: "puzzle_popup_dialog"});

	function init_complete_cb() {
	    // remove the little waitDiv notice
	    win.body().removeChild(dom.byId("waitDiv"));
		
		//spray out some admin functionality
		var take_a_break = dom.byId("take_a_break");
		take_a_break.appendChild(new formbutton({
			type: "break",
			label: "Take a break!", 
			onClick: function(){		
				solverstore.fetchItemByIdentity({
					identity: remote_user,
					onItem: function(item) {
					    //disable_store_ui_handlers()
						solverstore.setValue(item,"puzz","");
						solverstore.save({onError: error_cb});
					    //enable_store_ui_handlers()
					}
				});
				show_puzzle_dialog("");
				},
			}).domNode);


	    //hooks up our listeners initially
	    pbmrc.pb_log("init_complete_cb(): enabling connection handlers");
	    enable_store_ui_handlers();
	    
	    pbmrc.pb_log("init_complete_cb(): adding puzzles");
	    puzzstore.fetch({
				onItem: function(item){
				    add_puzz_ui(item);
				}
			    });

	    pbmrc.pb_log("init_complete_cb(): adding solver for remote_user: "+remote_user);
	    solverstore.fetchItemByIdentity({
						identity: remote_user,
						onItem: function(item) {
						    pbmrc.pb_log("init_complete_cb: solverstore.fetchItemByIdentity:onItem: item="+item, 3);
						    if(item != null) {
							add_solver_ui(item);
						    }
						},
						onError: function(error) {
						    warning_cb("could not find solver "+remote_user+" error: "+error);
						}
					    });
					    
	    pbmrc.pb_log("init_complete_cb(): init complete");		
	}
	
	function enable_store_ui_handlers(){
		add_puzz_ui_handler_connection = connect.connect(puzzstore,"onNew",add_puzz_ui);
		remove_puzz_ui_handler_connection = connect.connect(puzzstore,"onDelete",remove_puzz_ui);
		update_puzz_ui_handler_connection = connect.connect(puzzstore,"onSet",update_puzz_ui);
		update_solver_ui_handler_connection = connect.connect(solverstore,"onSet",update_solver_ui);
	}
	
	function disable_store_ui_handlers(){
		connect.disconnect(add_puzz_ui_handler_connection);
		connect.disconnect(remove_puzz_ui_handler_connection);
		connect.disconnect(update_puzz_ui_handler_connection);
	        connect.disconnect(update_solver_ui_handler_connection);
	}

	function choose_status_image(item){
		pbmrc.pb_log("choose_status_item()",2);
		var html_msg = "";
		var my_status = puzzstore.getValue(item,"status");
		if(my_status == "New"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/new.png\" title=\"New\" alt=\"new\" >";
		}else if (my_status == "Being worked"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/work.png\" title=\"Being worked\" alt=\"being worked\">";
		}else if (my_status == "Needs eyes"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/eyes.png\" title=\"Needs eyes\" alt=\"needs eyes\">";
		}else if (my_status == "Solved"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/solved.png\" title=\"Solved\" alt=\"solved\">";
		}else if (my_status == "Critical"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/critical.png\" title=\"Critical\" alt=\"critical\">";
		}else if (my_status == "Unnecessary"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/unnecessary.png\" title=\"Unnecessary\" alt=\"unnecessary\">";
		}else if (my_status == "WTF"){
			html_msg = "<img class=\"pi_icon\" src=\"../images/hazard.png\" title=\"WTF\" alt=\"WTF\">";
		}else{
			html_msg = "X"
		}
		
		return html_msg;
	}
	
	function add_puzz_ui(item, parentinfo){
		pbmrc.pb_log("add_puzz_ui()",2);
		var name = puzzstore.getValue(item,"name");
		
		var puzzinfo = domconstruct.create("div", {class: "pi_container", id: "puzzleinfo_div_"+name});

		//the status image
		var statusimg_span = domconstruct.create("span", {id: "pi_statusimg_span_"+name, 
								  class: "pi_status",
								  innerHTML: choose_status_image(item)});
		connect.connect(statusimg_span,"onclick",function () {show_puzzle_dialog(name);});
		puzzinfo.appendChild(statusimg_span);
			
		//the Puzzle name
		var namespan = domconstruct.create("span", {id: "pi_name_span_"+name, class: "pi_name", innerHTML: name});
		puzzinfo.appendChild(namespan);
		
	        //links to spreadsheet and puzzle pages 
  	        var links_span = domconstruct.create("span",{id: "pi_links_span_"+name, class: "pi_links"});

	        // add google spreadsheets link if it is not null
   	        var drive_uri = encodeURI(puzzstore.getValue(item,"drive_uri"));
	        var drive_link = domconstruct.create("a",{id: "pi_links_drive_"+name, class: "pi_drive_link", target: "_drive", innerHTML: "<img class=\"pi_icon\" src=\"../images/spreadsheet.png\" title=\"Spreadsheet\" alt=\"spreadsheet\">"});
	        if(drive_uri != "") {
		    drive_link.href = drive_uri;
		} else {
		    domclass.add(drive_link,"missing_link");
		}
	        links_span.appendChild(drive_link);

	        // add puzzle link if it is not null
 	        var puzzle_uri = encodeURI(puzzstore.getValue(item,"puzzle_uri"));
	        var puzz_link = domconstruct.create("a",{id: "pi_links_puzz_"+name, class: "pi_puzz_link", target: "_puzz", innerHTML: "<img class=\"pi_icon\" src=\"../images/puzzle.png\" title=\"Puzzle\" alt=\"puzzle\">"});
	        if(puzzle_uri != "") {
		    puzz_link.href = puzzle_uri;
		} else {
		    domclass.add(puzz_link,"missing_link");
		}
	        links_span.appendChild(puzz_link);

	        puzzinfo.appendChild(links_span);

		//the answer 
	        var answer_span = domconstruct.create("span", {id: "pi_answer_span_"+name, class: "pi_answer", innerHTML: puzzstore.getValue(item,"answer")});
		puzzinfo.appendChild(answer_span);			


	        set_status(puzzinfo, puzzstore.getValue(item,"status"));
		roundboxes[puzzstore.getValue(item,"round")].appendChild(puzzinfo);

	    wall.reload(); //may not need this for adding puzzles
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
			pbmrc.pb_log("looking for pi_statusimg_span_"+name);
			dom.byId("pi_statusimg_span_"+name).innerHTML=choose_status_image(item);
		        set_status("puzzleinfo_div_"+name, puzzstore.getValue(item,"status"));
		} else if ( attribute == "answer"){
			dom.byId("pi_answer_span_"+name).innerHTML=newValue;
		} else if ( attribute == "drive_uri"){
		    drive_link = dom.byId("pi_links_drive_"+name);
		    drive_uri = newValue;
	            if(drive_uri != "") {
			drive_link.href = drive_uri;
			domclass.remove(drive_link,"missing_link");
		    } else {
			domclass.add(drive_link,"missing_link");
		    }
		} else if ( attribute == "puzzle_uri"){
		    puzz_link = dom.byId("pi_links_puzz_"+name);
		    puzzle_uri = newValue;
	            if(puzzle_uri != "") {
			puzz_link.href = puzzle_uri;
			domclass.remove(puzz_link,"missing_link");
		    } else {
			domclass.add(puzz_link,"missing_link");
		    }
		}
	}
	
	function set_status(id_or_node, status) {
	    statusclass = "status_"+status.replace(/\ /g,"_");
  	    domclass.replace(id_or_node, statusclass, "status_New status_Being_worked status_Needs_eyes status_Solved status_Critical status_Unnecessary status_WTF");
	}
	
	function add_solver_ui(item, parentinfo){
	    pbmrc.pb_log("add_solver_ui()",2);
	    var name = solverstore.getValue(item,"name");
	    pbmrc.pb_log("add_solver_ui: name="+name+" remote_user="+remote_user, 3);
	    if(name == remote_user) {
		var puzz = solverstore.getValue(item,"puzz");
		pbmrc.pb_log("add_solver_ui: puzz="+puzz, 3);
		// this is the data for the currently logged-in user
		update_solver_ui(item, "puzz", "", puzz);
	    } else {
		// don't care about other users		    
	    }
	}

	function update_solver_ui(item, attribute, oldValue, newValue){
	    pbmrc.pb_log("update_solver_ui()",2);
	    pbmrc.pb_log("update_solver_ui: name="+solverstore.getValue(item,"name")+" attribute="+attribute+" oldValue="+oldValue+" newValue="+newValue);
	    var name = solverstore.getValue(item,"name");
	    if(name == remote_user) {
		// this is an update to the currently logged-in user
		if (attribute == "puzz"){
		    if (oldValue != "") {
			// solver was previously working, unset activesolverpuzzle from old puzzle
			pbmrc.pb_log("update_solver_ui: removing activesolverpuzzle class from #puzzleinfo_div_"+oldValue, 3);
			domclass.remove("puzzleinfo_div_"+oldValue, "activesolverpuzzle");
		    } else {
		        // solver was previously sleeping, activate him
			pbmrc.pb_log("update_solver_ui: setting solver_active class on #solver_active_p",3);
                	domclass.replace(dom.byId("solver_active_p"),"solver_active","solver_inactive");
		    }
		    if (newValue != "") {
			// solver is now solving
			pbmrc.pb_log("update_solver_ui: setting solver_active class on #solver_active_p",3);
                	domclass.replace(dom.byId("solver_active_p"),"solver_active","solver_inactive");

			// set current puzzle name
			pbmrc.pb_log("update_solver_ui: setting contents of #current_puzzle_name to "+newValue,3);
			dom.byId("current_puzzle_name").innerHTML=newValue;

			// setting puzzleinfo_div for puzzle to activesolverpuzzle
			pbmrc.pb_log("update_solver_ui: adding activesolverpuzzle class to puzzleinfo_div_"+newValue, 3);
			domclass.add("puzzleinfo_div_"+newValue, "activesolverpuzzle");
		    } else {
			// solver is now sleeping, set solver_inactive
                	domclass.replace(dom.byId("solver_active_p"),"solver_inactive","solver_active");
			dom.byId("current_puzzle_name").innerHTML="";
		    }
		} else {
		    // don't care about other attributes
		}
	    } else {
		// don't care about other users
	    }
	}
	
	function show_puzzle_dialog(puzz){		
		if (puzz == ""){
			var goodnight_div = domconstruct.create("div", {innerHTML: "Enjoy your well-earned rest, "+remote_user+"!<br>"});
			goodnight_div.appendChild(new formbutton({
				label: "Logout", 
				type: "submit",
				onClick: function (){location.href=encodeURI("https://wind-up-birds.org/saml/module.php/core/as_logout.php?AuthId=default-sp&ReturnTo="+location.href);}}).domNode
			);
			puzzle_popup_dialog.set("title", "Sleep well.");
			puzzle_popup_dialog.set("content", goodnight_div);
		}else{
			var puzzinfo_div = domconstruct.create("div");
				
			puzzinfo_div.appendChild(new formbutton({
				type: "submit",
				label: remote_user+" is working on "+puzz+"!", 
				onClick: function(){
					solverstore.fetchItemByIdentity({
						identity: remote_user,
						onItem: function(item) {
							if(item != null) {
								pbmrc.pb_log(puzz+", "+remote_user);
								//disable_store_ui_handlers()
								solverstore.setValue(item,"puzz",puzz);
								solverstore.save({onError: error_cb});
								//enable_store_ui_handlers()
							}else{
								//TODO: if can't find this should alert the user!
								pbmrc.pb_log("solverstore.fetchitembyitentity for identity "+remote_user+" is null!\n",2);
							}
						}
					});}, 
					showLabel: true
				}).domNode);
			
			var status_dd_div = domconstruct.create("div", {innerHTML: "Update status: "});		
			puzzinfo_div.appendChild(status_dd_div);
				
			//puzzle specific jazz slurped out from the store:	
			puzzstore.fetchItemByIdentity({
					identity: puzz,
					onItem: function(item){
						var status_dd_select = new formselect({
							options: [
							{value: 'New', label: 'New'},
							{value: 'Being worked', label: 'Being worked'},
							{value: 'Needs eyes', label: 'Needs eyes'},
							/** Probably shouldn't be able to say, "Solved!" from this interface, because
							    you can't enter the answer here (only through pb.pl).
							   {value: 'Solved', label:'Solved'},**/
							{value: 'Critical', label:'Critical'},
							{value: 'Unnecessary', label:'Unnecessary'},
							{value: 'WTF', label:'WTF'}
							],
							onChange: function (){
									puzzstore.setValue(item,"status",status_dd_select.get("value"));
									//this would be nice, but it gets called immediately below
									//and closes the popup right away, so need some additional logic
									//puzzle_popup_dialog.hide();
							}
						});	
						status_dd_div.appendChild(status_dd_select.domNode);
						
						status_dd_select.set("value",puzzstore.getValue(item,"status"));

						//put spaces between solver names to wrap in dialog
						puzzinfo_div.appendChild(domconstruct.create("p",
							{innerHTML: "Current solvers: "+ puzzstore.getValue(item,"cursolvers").split(",").join(", ")}
						));
						puzzinfo_div.appendChild(domconstruct.create("p",
							{innerHTML: "All historical solvers: "+ puzzstore.getValue(item,"solvers").split(",").join(", ")}
						));
                                                puzzinfo_div.appendChild(domconstruct.create("p",
							{innerHTML: "Location: "+ puzzstore.getValue(item, "xyzloc")} 
						));
					        var comment_div = domconstruct.create("div", {innerHTML: "PB notes: "});
					        puzzinfo_div.appendChild(comment_div);
					        var comment_formtextbox = new formtextbox({
						    value: puzzstore.getValue(item,"comments"),
						    class:"comment_formtextbox",
						    onChange: function(){
							puzzstore.setValue(item,"comments",comment_formtextbox.get("value"));
						    }
						});
					        comment_div.appendChild(comment_formtextbox.domNode);
					}
			})
				
			puzzle_popup_dialog.set("title", puzz);
			puzzle_popup_dialog.set("content", puzzinfo_div);
		}
		puzzle_popup_dialog.show();
	}

	function roundlist_update_cb(my_roundlist) {
		//don't care.
	}
	
	function add_round_cb(roundname) {
		pbmrc.pb_log("add_round_cb(): adding round "+roundname);
		var round_id = "round_div_"+roundname;
                roundboxes[roundname] = domconstruct.create("div", {class: "round_container", id: round_id});
	    /*currently don't use the meta items for anything (always worried we won't have a round based meta system*/
                var meta_container = domconstruct.create("div", {class: "meta_container", id: "meta_container_"+roundname});
	    /*little widget to expand/collapse*/
	    var collapsor_span = domconstruct.create("span", {id: "collapsor_span_"+roundname,
                                                                  innerHTML: "<img class=\"pi_icon\" src=\"../images/down.png\" title=\"More\" alt=\"More\" >"});
	    meta_container.appendChild(collapsor_span);
	    connect.connect(collapsor_span,"onclick",function(){domclass.toggle(round_id,"hidden_round");domclass.toggle(collapsor_span,"hidden_round_img");wall.reload();});

	    /*if we wanted this, too, we'd have to get rid of the toggler*/
                /*var meta_status = domconstruct.create("div", {class: "meta_status", id: "meta_status_"+roundname});
                meta_container.appendChild(meta_status);*/
                var meta_name = domconstruct.create("div", {class: "meta_name", id: "meta_name_"+roundname, innerHTML: roundname});
	        meta_container.appendChild(meta_name);
	        var meta_links = domconstruct.create("div", {class: "meta_links", id: "meta_links_"+roundname});
	        meta_container.appendChild(meta_links);
	        var meta_answer = domconstruct.create("div", {class: "meta_answer", id: "meta_answer_"+roundname});
	        meta_container.appendChild(meta_answer);
	        roundboxes[roundname].appendChild(meta_container);
		summary.appendChild(roundboxes[roundname]);	
	    wall.reload();
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
		    id: "warning_dialog"
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
	var is_puzzleinteresting_patt = /^puzzles\/[^\/]*\/(answer|status|solvers|cursolvers|puzzle_uri|drive_uri|xyzloc|comments)$/;
	var is_any_version_patt = /^version/;
	function version_diff_filter(diff){
	    // N.B. all pbmrcs must listen to version!
	    pbmrc.pb_log("version_diff_filter()", 2);
 	    pbmrc.pb_log("version_diff_filter: before filtering: diff = ", 3);
	    pbmrc.pb_log(diff, 3);
	    filtered_diff = array.filter(diff, function(item){
				    remote_user_regex_string = "^solvers\/"+remote_user;
				    is_solver_remote_user = new RegExp(remote_user_regex_string);
				    return (is_any_version_patt.test(item) ||
					    is_addpuzzle_patt.test(item) || 
					    is_any_rounds_patt.test(item) || 
					    is_puzzleinteresting_patt.test(item) || 
					    is_solver_remote_user.test(item));
				});
 	    pbmrc.pb_log("version_diff_filter: after filtering: filtered_diff = ", 3);
	    pbmrc.pb_log(filtered_diff, 3);
	    return filtered_diff;
	}
	
	return {
		
		my_init: function(my_init_remote_user) {
		    remote_user = my_init_remote_user;
		    pbmrc.pb_log("my_init: remote_user is "+remote_user)
		    
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

	pbmrc.pb_log("starting Masonry");
        wall = new Masonry ( document.getElementById('summary_layout'), { columnWidth: 630 });
	pbmrc.pb_log("have Masonry:");
        pbmrc.pb_log(wall);


		},	
	    
	};
		
    });


