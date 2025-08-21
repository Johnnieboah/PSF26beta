#!/usr/bin/env python3
"""
Smart Roster Management System
Implements smart roster cut strategy and practice squad exemption
"""

import csv

def main():
    print('🎯 SMART ROSTER MANAGEMENT SYSTEM')
    print('=' * 80)
    
    # 2025 NFL Salary Cap (unchanged)
    NFL_SALARY_CAP = 255_400_000  # $255.4M
    
    print(f'📊 2025 NFL Salary Cap: ${NFL_SALARY_CAP:,} (UNCHANGED)')
    print('🎯 Implementing: Smart Cut Strategy + Practice Squad Exemption')
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
    
    # Analyze each team's roster for smart cut optimization
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
    
    print('📊 CURRENT SITUATION ANALYSIS:')
    print('=' * 80)
    
    # Analyze current situation
    teams_hard_to_cut = []
    teams_easy_to_cut = []
    
    for team_name in sorted(team_analysis.keys()):
        if team_name in team_mapping:
            total_contracts = team_analysis[team_name]['total_contracts']
            player_count = team_analysis[team_name]['player_count']
            over_cap = total_contracts - NFL_SALARY_CAP
            
            # Sort players by APY (highest to lowest) for current cut analysis
            players_sorted = sorted(team_analysis[team_name]['players'], key=lambda x: x['apy'], reverse=True)
            
            if player_count >= 20:
                top_20_cut_savings = sum(player['apy_dollars'] for player in players_sorted[:20])
                remaining_contracts = total_contracts - top_20_cut_savings
                
                # Analyze the impact of cutting top 20
                remaining_players = players_sorted[20:]
                if remaining_players:
                    avg_overall_remaining = sum(p['overall'] for p in remaining_players) / len(remaining_players)
                    top_players_lost = sum(1 for p in players_sorted[:20] if p['overall'] >= 85)
                else:
                    avg_overall_remaining = 0
                    top_players_lost = 0
                
                # Categorize difficulty
                if top_players_lost >= 5:
                    teams_hard_to_cut.append(team_name)
                else:
                    teams_easy_to_cut.append(team_name)
                
                print(f'{team_name:<20} | Over Cap: ${over_cap:>8,.0f} | Good Players Lost: {top_players_lost:>2} | Remaining Avg: {avg_overall_remaining:>5.1f}')
    
    print('=' * 80)
    print(f'Teams that will struggle: {len(teams_hard_to_cut)}')
    print(f'Teams that can easily cut: {len(teams_easy_to_cut)}')
    
    # Now analyze with smart cut strategy
    print(f'\n🎯 SMART CUT STRATEGY ANALYSIS:')
    print('=' * 80)
    
    print('Current System: "Cut top 20 highest-paid players"')
    print('Smart System: "Cut any 20 players strategically"')
    print()
    
    # Show how smart cuts would improve each struggling team
    print('📊 IMPROVEMENT WITH SMART CUT STRATEGY:')
    print('=' * 80)
    
    for team_name in teams_hard_to_cut:
        analysis = team_analysis[team_name]
        total_contracts = analysis['total_contracts']
        over_cap = total_contracts - NFL_SALARY_CAP
        
        # Sort players by efficiency (contract value vs overall rating)
        players = analysis['players']
        for player in players:
            # Calculate efficiency: lower is better (less contract per overall point)
            if player['overall'] > 0:
                player['efficiency'] = player['apy_dollars'] / player['overall']
            else:
                player['efficiency'] = float('inf')
        
        # Sort by efficiency (worst efficiency first - these are the best to cut)
        players_sorted_efficiency = sorted(players, key=lambda x: x['efficiency'], reverse=True)
        
        # Calculate smart cut savings (cut 20 worst efficiency players)
        if len(players_sorted_efficiency) >= 20:
            smart_20_cut_savings = sum(player['apy_dollars'] for player in players_sorted_efficiency[:20])
            remaining_contracts_smart = total_contracts - smart_20_cut_savings
            
            # Analyze smart cut impact
            remaining_players_smart = players_sorted_efficiency[20:]
            if remaining_players_smart:
                avg_overall_remaining_smart = sum(p['overall'] for p in remaining_players_smart) / len(remaining_players_smart)
                top_players_lost_smart = sum(1 for p in players_sorted_efficiency[:20] if p['overall'] >= 85)
            else:
                avg_overall_remaining_smart = 0
                top_players_lost_smart = 0
            
            print(f'{team_name}:')
            print(f'  Current over cap: ${over_cap:,}')
            print(f'  Smart cut savings: ${smart_20_cut_savings:,}')
            print(f'  Remaining contracts: ${remaining_contracts_smart:,}')
            print(f'  Cap compliant after smart cuts: {"✅ YES" if remaining_contracts_smart <= NFL_SALARY_CAP else "❌ NO"}')
            print(f'  Good players lost (smart cuts): {top_players_lost_smart} (was: {sum(1 for p in sorted(analysis["players"], key=lambda x: x["apy"], reverse=True)[:20] if p["overall"] >= 85)})')
            print(f'  Remaining roster avg: {avg_overall_remaining_smart:.1f}')
            print()
    
    # Practice Squad Exemption Analysis
    print(f'\n📊 PRACTICE SQUAD EXEMPTION ANALYSIS:')
    print('=' * 80)
    
    print('NFL Rule: Practice squad players don\'t count against salary cap')
    print('Implementation: Allow 16 players to practice squad (no cap hit)')
    print()
    
    for team_name in teams_hard_to_cut:
        analysis = team_analysis[team_name]
        total_contracts = analysis['total_contracts']
        over_cap = total_contracts - NFL_SALARY_CAP
        
        # Find 16 lowest-contract players for practice squad
        players_sorted_contract = sorted(analysis['players'], key=lambda x: x['apy_dollars'])
        practice_squad_savings = sum(player['apy_dollars'] for player in players_sorted_contract[:16])
        remaining_contracts_ps = total_contracts - practice_squad_savings
        
        print(f'{team_name}:')
        print(f'  Current over cap: ${over_cap:,}')
        print(f'  Practice squad savings: ${practice_squad_savings:,}')
        print(f'  Remaining contracts: ${remaining_contracts_ps:,}')
        print(f'  Cap compliant with PS: {"✅ YES" if remaining_contracts_ps <= NFL_SALARY_CAP else "❌ NO"}')
        print()
    
    # Combined Strategy Analysis
    print(f'\n🚀 COMBINED STRATEGY IMPACT:')
    print('=' * 80)
    
    print('Strategy 1: Smart Cut Strategy')
    print('  - Cut 20 worst efficiency players instead of 20 highest-paid')
    print('  - Reduces loss of good players significantly')
    print()
    
    print('Strategy 2: Practice Squad Exemption')
    print('  - Move 16 lowest-contract players to practice squad')
    print('  - No cap hit for these players')
    print('  - Very realistic NFL roster management')
    print()
    
    print('Combined Effect:')
    print('  - Teams can use smart cuts + practice squad to get under cap')
    print('  - Much better roster quality preservation')
    print('  - More strategic and realistic roster management')
    print('  - 100% preserves real NFL contract authenticity')
    print()
    
    print('🎯 IMPLEMENTATION RECOMMENDATION:')
    print('  1. Allow users to cut ANY 20 players (not just highest-paid)')
    print('  2. Implement practice squad for 16 players (no cap hit)')
    print('  3. Keep salary cap at $255.4M (unchanged)')
    print('  4. Provide efficiency metrics to help users make smart cuts')

if __name__ == "__main__":
    main()


