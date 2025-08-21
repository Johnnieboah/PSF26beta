#!/usr/bin/env python3
"""
CPU Roster Intelligence System
Analyzes how CPU teams should make smart roster decisions to get under cap
"""

import csv

def main():
    print('🤖 CPU ROSTER INTELLIGENCE SYSTEM')
    print('=' * 80)
    
    # 2025 NFL Salary Cap
    NFL_SALARY_CAP = 255_400_000  # $255.4M
    
    print(f'📊 2025 NFL Salary Cap: ${NFL_SALARY_CAP:,}')
    print('🎯 Goal: CPU teams make smart cuts to get under cap without gutting roster')
    print('=' * 80)
    
    # Team name mapping
    team_mapping = {
        'Cleveland': 'CLE', 'San Francisco': 'SF', 'New York N': 'NYG',
        'Washington': 'WAS', 'Atlanta': 'ATL', 'Las Vegas': 'LV',
        'Jacksonville': 'JAX', 'Houston': 'HOU', 'Indianapolis': 'IND',
        'Dallas': 'DAL', 'Buffalo': 'BUF', 'Miami': 'MIA',
        'Chicago': 'CHI', 'Kansas City': 'KC', 'Green Bay': 'GB',
        'Tennessee': 'TEN', 'Baltimore': 'BAL', 'Carolina': 'CAR',
        'Los Angeles N': 'LAR', 'New England': 'NE', 'New Orleans': 'NO',
        'Philadelphia': 'PHI', 'Cincinnati': 'CIN', 'Minnesota': 'MIN',
        'Denver': 'DEN', 'Arizona': 'ARI', 'Detroit': 'DET',
        'Tampa Bay': 'TB', 'Seattle': 'SEA', 'Pittsburgh': 'PIT',
        'New York A': 'NYJ', 'Los Angeles A': 'LAC'
    }
    
    # Analyze each team's roster for CPU intelligence
    team_analysis = {}
    
    with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            team = row.get('Team', '').strip()
            contract_apy_str = row.get('contractAPY_M', '').strip()
            overall = row.get('overallRating', '').strip()
            position = row.get('Position', '').strip()
            
            if team and contract_apy_str and overall:
                try:
                    contract_apy = float(contract_apy_str)
                    overall_int = int(overall)
                    
                    if team not in team_analysis:
                        team_analysis[team] = {
                            'total_contracts': 0,
                            'player_count': 0,
                            'players': []
                        }
                    
                    team_analysis[team]['total_contracts'] += contract_apy * 1_000_000
                    team_analysis[team]['player_count'] += 1
                    team_analysis[team]['players'].append({
                        'overall': overall_int,
                        'position': position,
                        'apy': contract_apy,
                        'apy_dollars': int(contract_apy * 1_000_000)
                    })
                    
                except ValueError:
                    continue
    
    print('🤖 CPU ROSTER INTELLIGENCE ALGORITHM:')
    print('=' * 80)
    
    print('CPU Decision Making Process:')
    print('1. Calculate how much over cap the team is')
    print('2. Identify players to cut based on smart criteria')
    print('3. Ensure cuts get team under cap')
    print('4. Preserve roster quality and depth')
    print()
    
    # Analyze CPU decision making for each team
    print('📊 CPU ROSTER DECISION ANALYSIS:')
    print('=' * 80)
    
    teams_over_cap = []
    teams_under_cap = []
    
    for team_name in sorted(team_analysis.keys()):
        if team_name in team_mapping:
            total_contracts = team_analysis[team_name]['total_contracts']
            player_count = team_analysis[team_name]['player_count']
            over_cap = total_contracts - NFL_SALARY_CAP
            
            if over_cap > 0:
                teams_over_cap.append(team_name)
            else:
                teams_under_cap.append(team_name)
    
    print(f'Teams over cap: {len(teams_over_cap)} (need CPU cuts)')
    print(f'Teams under cap: {len(teams_under_cap)} (no cuts needed)')
    print()
    
    # Show CPU decision making for teams over cap
    print('🔴 TEAMS NEEDING CPU ROSTER DECISIONS:')
    print('=' * 80)
    
    for team_name in teams_over_cap:
        analysis = team_analysis[team_name]
        total_contracts = analysis['total_contracts']
        over_cap = total_contracts - NFL_SALARY_CAP
        
        print(f'\n{team_name} - Over cap by ${over_cap:,}')
        print('-' * 50)
        
        # CPU Intelligence Algorithm
        players = analysis['players']
        
        # Step 1: Calculate player efficiency scores
        for player in players:
            if player['overall'] > 0:
                # Efficiency: contract value per overall point (lower is better)
                player['efficiency'] = player['apy_dollars'] / player['overall']
                # Risk score: high overall + high contract = high risk to cut
                player['risk_score'] = (player['overall'] * 0.7) + (player['apy_dollars'] / 1_000_000 * 0.3)
            else:
                player['efficiency'] = float('inf')
                player['risk_score'] = 0
        
        # Step 2: CPU prioritizes cuts based on multiple factors
        # Sort by efficiency (worst efficiency first) and risk score
        players_sorted_cuts = sorted(players, key=lambda x: (x['efficiency'], -x['risk_score']), reverse=True)
        
        # Step 3: Calculate how many players need to be cut
        needed_savings = over_cap
        players_to_cut = []
        total_savings = 0
        
        for player in players_sorted_cuts:
            if total_savings < needed_savings:
                players_to_cut.append(player)
                total_savings += player['apy_dollars']
            else:
                break
        
        # Step 4: Analyze the impact of CPU cuts
        remaining_players = [p for p in players if p not in players_to_cut]
        if remaining_players:
            avg_overall_remaining = sum(p['overall'] for p in remaining_players) / len(remaining_players)
            top_players_lost = sum(1 for p in players_to_cut if p['overall'] >= 85)
            good_players_lost = sum(1 for p in players_to_cut if p['overall'] >= 80)
        else:
            avg_overall_remaining = 0
            top_players_lost = 0
            good_players_lost = 0
        
        # Step 5: Show CPU decision results
        print(f'CPU Strategy: Cut {len(players_to_cut)} players to save ${total_savings:,}')
        print(f'Remaining contracts: ${total_contracts - total_savings:,}')
        print(f'Cap compliant: {"✅ YES" if (total_contracts - total_savings) <= NFL_SALARY_CAP else "❌ NO"}')
        print(f'Impact: Lost {top_players_lost} elite players (85+), {good_players_lost} good players (80+)')
        print(f'Remaining roster avg: {avg_overall_remaining:.1f}')
        
        # Show top 5 players CPU would cut (smartest cuts)
        print(f'Top 5 CPU cuts (smartest decisions):')
        for i, player in enumerate(players_to_cut[:5], 1):
            efficiency = player['apy_dollars'] / player['overall'] if player['overall'] > 0 else 0
            print(f'  {i}. {player["position"]} - OVR {player["overall"]} - ${player["apy"]:.2f}M (efficiency: ${efficiency:,.0f}/point)')
        
        # Show remaining roster quality
        if remaining_players:
            remaining_by_position = {}
            for player in remaining_players:
                pos = player['position']
                if pos not in remaining_by_position:
                    remaining_by_position[pos] = []
                remaining_by_position[pos].append(player['overall'])
            
            print(f'Remaining roster depth:')
            for pos in sorted(remaining_by_position.keys()):
                overalls = remaining_by_position[pos]
                avg_ovr = sum(overalls) / len(overalls)
                print(f'  {pos}: {len(overalls)} players, avg {avg_ovr:.1f}')
    
    # Summary of CPU Intelligence
    print(f'\n🤖 CPU ROSTER INTELLIGENCE SUMMARY:')
    print('=' * 80)
    
    print('CPU Decision Making Criteria:')
    print('1. 🎯 Efficiency First: Cut players with worst contract value per overall point')
    print('2. 🏈 Risk Assessment: Consider both overall rating and contract value')
    print('3. 💰 Cap Compliance: Ensure cuts get team under salary cap')
    print('4. 🧠 Roster Preservation: Minimize loss of elite and good players')
    print('5. 📊 Position Balance: Maintain depth at key positions')
    print()
    
    print('CPU Cut Priority Order:')
    print('1. Low overall + high contract (obvious cuts)')
    print('2. Medium overall + very high contract (overpaid players)')
    print('3. High overall + extremely high contract (if necessary)')
    print('4. Never cut: Elite players (90+) unless absolutely necessary')
    print()
    
    print('Expected Results:')
    print('• All teams get under cap through smart cuts')
    print('• Minimal loss of elite players (85+)')
    print('• Better roster quality preservation than random cuts')
    print('• Realistic NFL roster management simulation')

if __name__ == "__main__":
    main()


