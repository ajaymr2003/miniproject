import 'package:flutter/material.dart';

class EVUserDashboard extends StatefulWidget {
  final String role;
  const EVUserDashboard({super.key, required this.role});

  @override
  State<EVUserDashboard> createState() => _EVUserDashboardState();
}

class _EVUserDashboardState extends State<EVUserDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // TODO: Add navigation logic for each tab if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'EV Smart Charge',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Battery Status Section
            const Text(
              "Battery Status",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "78%",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Current Location: JP Nagar, Bengaluru",
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Enable Live Tracking",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Text(
                        "Monitor your EV’s battery in real-time and get alerts.",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade100,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text("Enable"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    "https://images.unsplash.com/photo-1612367296715-0b0138a0b91a",
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nearby Stations
            const Text(
              "Nearby Stations",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  stationCard(
                    "ChargePoint - Downtown",
                    "0.5 mi, 3 slots",
                    "https://via.placeholder.com/150",
                  ),
                  stationCard(
                    "EVgo - City Center",
                    "1.2 mi, 2 slots",
                    "https://via.placeholder.com/150",
                  ),
                  stationCard(
                    "Electra Mall",
                    "2.1 mi, 4 slots",
                    "https://via.placeholder.com/150",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  "Find Best Station",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Charging History
            const Text(
              "Charging History",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Recent Sessions: 3"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                historyBar("Mon", 70),
                historyBar("Tue", 40),
                historyBar("Wed", 50),
                historyBar("Thu", 80),
                historyBar("Fri", 30),
                historyBar("Sat", 60),
                historyBar("Sun", 50),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.blueGrey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: _selectedIndex == 0
                ? const Icon(Icons.home)
                : const Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 1
                ? const Icon(Icons.map)
                : const Icon(Icons.map_outlined),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 2
                ? const Icon(Icons.history)
                : const Icon(Icons.history_outlined),
            label: "History",
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 3
                ? const Icon(Icons.person)
                : const Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget stationCard(String title, String subtitle, String imageUrl) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imageUrl, height: 100, fit: BoxFit.cover),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget historyBar(String day, double height) {
    return Column(
      children: [
        Container(
          height: height,
          width: 14,
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
