import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:vehicle_data_test/widgets/data_card.dart';

class ObdDataPage extends StatefulWidget {
  const ObdDataPage({super.key,});

  @override
  State<ObdDataPage> createState() => _ObdDataPageState();
}

class _ObdDataPageState extends State<ObdDataPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _flDoor = false;
  bool _frDoor = false;
  bool _rlDoor = false;
  bool _rrDoor = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          _files(),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _vehicle1()),
                Expanded(child: _vehicle2()),
                Expanded(child: _vehicle3()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _files() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom:12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('데이터 파일', style:TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('data.csv',style:TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _vehicle1() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom:12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('파워트레인', style:TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(label: 'Engine RPM', value: 'value'),
          DataCard(label: 'AcceleratorPedalPosition', value: 'value'),
          DataCard(label: 'FuelLevel', value: 'value'),
          DataCard(label: 'TripDistance', value: 'value'),
        ],
      ),
    );
  }

  Widget _vehicle2() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom:12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('주행 상태', style:TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(label: 'VehicleSpeed', value: 'value'),
          DataCard(label: 'TimeSinceStart', value: 'value'),
        ],
      ),
    );
  }

  Widget _vehicle3() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom:12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('위치 정보', style:TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(label: 'Latitude', value: 'value'),
          DataCard(label: 'Longitude', value: 'value'),
        ],
      ),
    );
  }

}