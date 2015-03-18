$(document).ready(function () {
  ({

    when_cat  : "li.section-main",
    data_path : ($(location).attr('pathname') + '/main/chart').replace('//', '/'),
    torso     : { width : 375, height : 200, right : 20 },

    init : function () {
      var self = this;
      
      if ( $(self.when_cat).length <= 0 ){
        return false;
      }

      self.run_autoupdate();
    },

    run_autoupdate : function () {
      var self = this;
      self.draw_chart();
      setInterval(function () { self.draw_chart() }, 5000);
    },

    draw_chart : function () {
      var self = this;

      $.getJSON(self.data_path, function (data) {

        for (var i = 0; i < data.length; i++) {
          data[i].date = new Date(data[i].date*1000)
        }

        MG.data_graphic({
          
          data: data,          
          full_width: true,

          height: self.torso.height * 3 / 2,
          right: self.torso.right,

          target: ".chart",
          x_extended_ticks: true,
          x_accessor: "date",
          y_accessor: "value",
          interpolate: "linear",
          // y_scale_type:'log'
        });

        $('.loader').hide();
        $('.chart').addClass('animated fadeIn');

      });

    }

  }).init();
});



	
	