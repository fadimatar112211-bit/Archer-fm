import 'dart:math' as math;
import 'package:flutter/material.dart';

/// First playable 2.5D presentation of the four-sided Archer FM arena.
/// Coordinates and objective counts follow ArcherFM_Map_Design / map package.
class ArenaMapScreen extends StatelessWidget {
  const ArenaMapScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101b1b),
    appBar: AppBar(
      title: const Text('ساحة المعركة · ٤ لاعبين'),
      backgroundColor: const Color(0xff172927),
    ),
    body: SafeArea(
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center,
            children: [
              _Legend(const Color(0xff438ce8), 'الأزرق · الجنوب'),
              _Legend(const Color(0xffed5b54), 'الأحمر · الشرق'),
              _Legend(const Color(0xffe8b83e), 'الأصفر · الشمال'),
              _Legend(const Color(0xffa96be8), 'البنفسجي · الغرب'),
            ]),
        ),
        Expanded(child: InteractiveViewer(
          minScale: .55, maxScale: 4, boundaryMargin: const EdgeInsets.all(80),
          child: Center(child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _ArenaPainter(), child: const SizedBox.expand()),
          )),
        )),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('٢٨ بلورة · ٨ أبراج · ٨ جسور · ١٧ معسكر وحوش · ٥ نقاط سيطرة',
            textAlign: TextAlign.center, style: TextStyle(color: Color(0xffd4e5dc), fontSize: 12)),
        ),
      ]),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color; final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Color(0xffd4e5dc), fontSize: 11)),
  ]);
}

class _ArenaPainter extends CustomPainter {
  static const colors = [Color(0xff438ce8), Color(0xffed5b54), Color(0xffe8b83e), Color(0xffa96be8)];
  static const spawns = [Offset(0,-33.5), Offset(33.5,0), Offset(0,33.5), Offset(-33.5,0)];
  static const castleCenters = [Offset(0,-40), Offset(40,0), Offset(0,40), Offset(-40,0)];
  static const crystalSets = [
    [Offset(0,-46),Offset(-8,-42),Offset(8,-42),Offset(-13,-36),Offset(13,-36),Offset(-11,-28),Offset(11,-28)],
    [Offset(46,0),Offset(42,-8),Offset(42,8),Offset(36,-13),Offset(36,13),Offset(28,-11),Offset(28,11)],
    [Offset(0,46),Offset(8,42),Offset(-8,42),Offset(13,36),Offset(-13,36),Offset(11,28),Offset(-11,28)],
    [Offset(-46,0),Offset(-42,8),Offset(-42,-8),Offset(-36,13),Offset(-36,-13),Offset(-28,11),Offset(-28,-11)],
  ];

  Offset project(Offset p, Size s) {
    final unit = math.min(s.width, s.height) / 108;
    return Offset(s.width/2 + (p.dx-p.dy)*unit*.5, s.height/2 + (p.dx+p.dy)*unit*.25);
  }

  Path diamond(Offset c, double w, double h) => Path()
    ..moveTo(c.dx,c.dy-h/2)..lineTo(c.dx+w/2,c.dy)
    ..lineTo(c.dx,c.dy+h/2)..lineTo(c.dx-w/2,c.dy)..close();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width,size.height)/108;
    canvas.drawRect(Offset.zero & size, Paint()..color=const Color(0xff172a27));
    // Grass base and outer boundary.
    final center=Offset(size.width/2,size.height/2);
    canvas.drawPath(diamond(center, unit*96, unit*48), Paint()..color=const Color(0xff527d4a));
    // Central river ring with four main crossings and diagonal flank crossings.
    canvas.drawPath(diamond(center, unit*46, unit*23), Paint()..color=const Color(0xff267c91));
    canvas.drawPath(diamond(center, unit*35, unit*17.5), Paint()..color=const Color(0xff527d4a));
    final bridges=[Offset(0,-22.2),Offset(22.2,0),Offset(0,22.2),Offset(-22.2,0),
      Offset(14,-14),Offset(14,14),Offset(-14,14),Offset(-14,-14)];
    for (var i=0;i<bridges.length;i++) {
      final p=project(bridges[i],size);
      final w=(i<4?8:4)*unit*.72;
      canvas.drawPath(diamond(p,w*1.6,w*.8),Paint()..color=const Color(0xffb99a68));
      canvas.drawPath(diamond(p,w*1.6,w*.8),Paint()..style=PaintingStyle.stroke
        ..strokeWidth=1..color=const Color(0xffe5c991));
    }
    // Subtle terrain grid.
    final gridPaint=Paint()..color=const Color(0x2251a078)..strokeWidth=.55;
    for(var i=-48;i<=48;i+=4){
      final a=project(Offset(i,-48),size), b=project(Offset(i,48),size);
      final c=project(Offset(-48,i),size), d=project(Offset(48,i),size);
      canvas.drawLine(a,b,gridPaint); canvas.drawLine(c,d,gridPaint);
    }
    // Four castles, their seven crystals, towers and spawn markers.
    for(var p=0;p<4;p++){
      final castle=project(castleCenters[p],size);
      canvas.drawPath(diamond(castle,unit*10,unit*5),Paint()..color=colors[p].withAlpha(210));
      canvas.drawPath(diamond(castle,unit*10,unit*5),Paint()..style=PaintingStyle.stroke
        ..strokeWidth=1.5..color=Colors.white);
      for(var j=0;j<7;j++){
        final c=project(crystalSets[p][j],size);
        final r=unit*(j==0?2.6:1.8);
        final path=Path()..moveTo(c.dx,c.dy-r)..lineTo(c.dx+r*.62,c.dy)
          ..lineTo(c.dx,c.dy+r)..lineTo(c.dx-r*.62,c.dy)..close();
        canvas.drawPath(path,Paint()..color= j==0?const Color(0xff7ff5ff):colors[p].withAlpha(235));
        canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=.8..color=Colors.white);
      }
      for(final dx in [-7.0,7.0]){
        final t=project(castleCenters[p]+Offset(dx, p.isEven?7:-7),size);
        canvas.drawCircle(t,unit*1.5,Paint()..color=const Color(0xffffd36b));
      }
      final spawn=project(spawns[p],size);
      canvas.drawCircle(spawn,unit*2.2,Paint()..color=colors[p]);
      canvas.drawCircle(spawn,unit*2.2,Paint()..style=PaintingStyle.stroke..strokeWidth=1.3..color=Colors.white);
    }
    // Neutral control points and monster camps.
    for(final p in [Offset.zero,Offset(38,-38),Offset(38,38),Offset(-38,38),Offset(-38,-38)]){
      final c=project(p,size); canvas.drawCircle(c,unit*2.0,Paint()..color=const Color(0xffffdc69));
      canvas.drawCircle(c,unit*2.0,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white);
    }
    for(final p in [Offset(25.5,-25.5),Offset(11,-11),Offset(25.5,25.5),Offset(11,11),
      Offset(-25.5,25.5),Offset(-11,11),Offset(-25.5,-25.5),Offset(-11,-11),
      Offset(-21,-37),Offset(21,-37),Offset(37,-21),Offset(37,21),
      Offset(21,37),Offset(-21,37),Offset(-37,21),Offset(-37,-21)]){
      final c=project(p,size); canvas.drawCircle(c,unit*1.25,Paint()..color=const Color(0xffd5a45e));
    }
    // Center drake marker.
    final drake=project(Offset.zero,size);
    canvas.drawCircle(drake,unit*3.3,Paint()..style=PaintingStyle.stroke..strokeWidth=1.6..color=const Color(0xffffe28a));
    final tp=TextPainter(text:const TextSpan(text:'التنين',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.bold)),
      textDirection:TextDirection.rtl)..layout();
    tp.paint(canvas,drake+Offset(-tp.width/2,unit*3.6));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate)=>false;
}
