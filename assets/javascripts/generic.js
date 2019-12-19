/**************************************
  Generic
***************************************/

RB.Generic = RB.Object.create(RB.Issue, {

  initialize: function(el, config){
    var j;  // This ensures that we use a local 'j' variable, not a global one.

    this.$ = j = RB.$(el);
    this.el = el;
    this.config = config || {};

    //j.addClass("task"); // If node is based on #task_template, it doesn't have the task class yet

    // Associate this object with the element for later retrieval
    j.data('this', this);

    if (RB.permissions.update_tasks) {
      j.delegate('.editable', 'click', this.handleClick);
    }
  },

  beforeSave: function(){
    var c = this.$.find('select.assigned_to_id').find(':selected').attr('color');
    var c_light = this.$.find('select.assigned_to_id').find(':selected').attr('color_light');
    // Only change color of task if assigned_to_id has a selected user/group
    if(c!=undefined){
      this.$.css('background-color', c);
      this.$.css('background', '-webkit-gradient(linear, left top, left bottom, from('+c_light+'), to('+c+'))');
      this.$.css('background', '-moz-linear-gradient(top, '+c_light+', '+c+')');
      this.$.css('filter', 'progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr='+c_light+',EndColorStr='+c+')');
    }
  },

  editorDisplayed: function(dialog){
    var dialog_bgcolor=this.$.css('background-color'),
        dialog_bg=this.$.css('background-image');
    if(dialog_bgcolor=='initial'||dialog_bgcolor=='rgba(0, 0, 0, 0)'||dialog_bgcolor=='transparent'){
      // Chrome could not handling background-color css when use -webkit-gradient.
      if(dialog_bg){
        dialog.parents('.ui-dialog').css('background', dialog_bg);
      } else {
        dialog.parents('.ui-dialog').css('background', '-webkit-gradient(linear, left top, left bottom, from(#eee), to(#aaa))');
        dialog.parents('.ui-dialog').css('background', '-moz-linear-gradient(top, #eee, #aaa)');
        dialog.parents('.ui-dialog').css('filter', 'progid:DXImageTransform.Microsoft.Gradient(Enabled=1,GradientType=0,StartColorStr=#eeeeee,EndColorStr=#aaaaaa)');
      }
    } else {
      dialog.parents('.ui-dialog').css('background-color', dialog_bgcolor);
    }
  },

  getType: function(){
    return this.config.type_name || "Task";
  },

  markIfClosed: function(){
    if(this.$.parents('td').first().hasClass('closed')){
      this.$.addClass('closed');
    } else {
      this.$.removeClass('closed');
    }
  },

  saveDirectives: function(){
    var j = this.$;
    var url;
    var nxt
    if (this.$.hasClass('rowelement')) {
        nxt = j.parent().parent().next().find('.model.rowelement');
    }
    else {
        nxt = j.next();
        while (nxt.length && !nxt.hasClass('model')) { //skip non-models
            nxt = nxt.next();
        }
    }
    var project = j.parents('tr').find('.story .project .v');
    var cellID = j.parents('td').first().attr('id').split("_");
    var data = j.find('.editor').serialize() +
               "&genericboard_id=" + RB.constants.genericboard_id +
               "&row_id=" + cellID[0] +
               "&col_id=" + cellID[1] +
               "&next=" + ((nxt.length==1 && nxt.data('this')) ? nxt.data('this').getID() : '') +
               (this.isNew() ? "" : "&id=" + j.children('.id').text());

    throw 'aFit';
    if( project.length){
      data += "&project_id=" + project.text();
    }
    if (RB.constants.genericboard_active_filters) {
      for (var k in RB.constants.genericboard_active_filters) {
        data += "&"+k+"="+RB.constants.genericboard_active_filters[k];
      }
    }

    if( this.isNew() ){
      url = RB.urlFor( 'create_generic' );
    } else {
      url = RB.urlFor( 'update_generic', { id: this.getID() } );
      data += "&_method=put";
    }

    return {
      url: url,
      data: data
    };
  },

  afterCreate: function(data, textStatus, xhr){
    //fixup new row ids
    if (this.$.hasClass('rowelement')) {
        var id = this.$.attr('id').split('_')[1];
        var row = this.$.parents('tr');
        row.attr('id', 'swimlane-'+id);
        row.children('td').attr('id', function(index, oldval){
            console.log(index, oldval);
            return id+'_'+oldval.split('_')[1];
        });
        RB.$('#taskboard').data('this').init_add_buttons();
    }
  },

  cancelEdit: function(obj){
    this.endEdit();
    if (typeof obj == 'undefined') {
        obj = this;
    }
    obj.$.find('.editors').remove();
    if(this.isNew()){
        if (this.$.hasClass('rowelement')) {
          this.$.parents('tr').remove();
        }
        this.$.remove();
    }
  },

  beforeSaveDragResult: function(){
    if(this.$.parents('td').first().hasClass('closed')){
      // This is only for the purpose of making the Remaining Hours reset
      // instantaneously after dragging to a closed status. The server should
      // still make sure to reset the value to be sure.
      if (this.$children('.remaining_hours.editor'))
      {
        this.$.children('.remaining_hours.editor').val('');
        this.$.children('.remaining_hours.editable').text('');
      }
    }
  }

});
