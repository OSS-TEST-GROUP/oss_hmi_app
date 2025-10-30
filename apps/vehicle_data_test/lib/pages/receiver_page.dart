import 'package:flutter/material.dart';
import 'package:vehicle_data_test/grpc/grpc_client.dart';

class ReceiverPage extends StatelessWidget {
  const ReceiverPage({super.key, required this.cloud});
  final GrpcClient cloud;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: cloud.events, // 클라이언트가 직접 내놓는 스트림
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              '수신 대기 중...',
              style: TextStyle(color: Colors.grey)
            ));
        }
        final dp = snapshot.data!;
        final rows = <Widget>[];
        for (final pkg in dp.data) {
          for (final p in pkg.dp) {
            rows.add(ListTile(
              title: Text(pkg.path),
              subtitle: Text(p.ts),
              trailing: Text(p.value),
            ));
          }
        }
        if (rows.isEmpty) {
          return const Center(child: Text('데이터 없음'));
        }
        return ListView.separated(
          itemBuilder: (_, i) => rows[i],
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: rows.length,
        );
      },
    );
  }
}
